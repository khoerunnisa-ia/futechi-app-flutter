/// Port logika `miniaturFutechi/src/main.cpp` ke aplikasi, sebagai
/// **simulator deterministik (mode Overwatch)** + kontrak perintah MQTT
/// untuk firmware mendatang.
///
/// Latar belakang (lihat `implementasi_IoT.md` di root repo):
///
/// - Firmware miniatur tidak punya WiFi/MQTT — satu-satunya input fisik
///   adalah tombol UP/DOWN, dan siklusnya berjalan terus-menerus memakai
///   timing yang persis sama setiap ulangan.
/// - Karena firmware tidak boleh diubah (sudah ter-deploy), aplikasi tidak
///   bisa mengirim perintah nyata. Yang dilakukan di sini: memodelkan ulang
///   siklus yang sama lalu menampilkan estimasi kondisi perangkat
///   ("Overwatch"), dikalibrasi lewat tombol saat perangkat baru menyala.
/// - Struktur koneksi MQTT (`MiniaturLink`, topik `client3/...`) tetap
///   dibangun penuh dan **forward-compatible**: begitu firmware mendapat
///   dukungan MQTT, kontrol live langsung berfungsi tanpa perubahan UI.
///
/// Timing diambil dari kode firmware, bukan dari komentar kodenya —
/// komentar `loop()` menulis "Tunggu 10 detik" padahal `WAIT_BETWEEN`
/// bernilai 30000 ms. Durasi gerakan 5000 step dihitung dari profil
/// akselerasi trapesium: `STEPPER_ACCELERATION=200`, `STEPPER_MAX_SPEED=200`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

// =====================================================
// KONSTANTA FIRMWARE (mirror include/config.h & main.cpp)
// =====================================================

/// MOTOR1_DISTANCE / MOTOR2_DISTANCE (jumlah langkah motor).
const int miniaturStepsPerCycle = 5000;

/// STEPPER_ACCELERATION (step/s²).
const double miniaturAccelStepsPerS2 = 200.0;

/// STEPPER_MAX_SPEED (step/s).
const double miniaturMaxSpeedStepsPerS = 200.0;

/// Durasi satu gerakan 5000 step dengan profil trapesium:
/// 1 s akselerasi (100 step) + 24 s konstan (4800 step) + 1 s deselerasi
/// (100 step) = 26 s. [MiniaturSimulator.stepsDoneInMotion] memodelkan
/// posisi step di dalam window ini.
const int miniaturMotionMs = 26000;

/// INITIAL_WAIT (ms) — standby sebelum siklus pertama.
const int miniaturInitialWaitMs = 3000;

/// WAIT_BETWEEN (ms) — jeda antar gerakan.
const int miniaturWaitBetweenMs = 30000;

/// LAMP_INTERVAL (ms) — kedip lampu indikator saat motor bergerak.
const int miniaturLampIntervalMs = 1000;

/// HOMING_TIMEOUT (ms) — di firmware, gagal menemukan ZERO dalam batas
/// ini memicu `systemError()` (perangkat berhenti total sampai direset).
const int miniaturHomingTimeoutMs = 60000;

/// Nomor lagu di microSD DFPlayer. 1–3 dapat dipilih lewat tombol
/// UP/DOWN fisik; 4 = standby (otomatis). Pilihan tersimpan di NVS
/// firmware (`Preferences`, namespace `futechi`).
const int miniaturStandbyTrack = 4;
const int miniaturMinTrack = 1;
const int miniaturMaxTrack = 3;

/// Total satu siklus penuh: maju bersama + jeda + M1 mundur + jeda +
/// M2 mundur + jeda = 3 × (26000 + 30000) ms = 168 s.
const int miniaturCycleMs = 3 * (miniaturMotionMs + miniaturWaitBetweenMs);

// =====================================================
// FASE / SEGMEN SIKLUS
// =====================================================

/// Fase kehidupan perangkat sesuai alur `setup()` + `loop()`.
enum MiniaturSegment {
  /// Homing berjalan (durasi variatif, maks [miniaturHomingTimeoutMs]
  /// per motor; aplikasi tidak bisa mengetahui kapan selesai tanpa
  /// telemetria — perlu kalibrasi manual dari pengguna).
  homing('Homing ke posisi ZERO', false),

  /// dfplayerPlay(STANDBY_TRACK) + waitSeconds(INITIAL_WAIT).
  standbyWait('Standby — lagu 004, menunggu siklus', false),

  /// moveBothForward(): kedua motor maju 5000 step bersamaan + lagu pilihan.
  bothForward('Kedua motor maju 5000 step', true),

  /// Jeda sesudah maju bersama.
  waitAfterBoth('Tunggu antar gerakan', false),

  /// moveMotor1Backward() + lagu.
  motor1Backward('Motor 1 mundur 5000 step', true),

  /// Jeda sesudah M1 mundur.
  waitAfterM1('Tunggu antar gerakan', false),

  /// moveMotor2Backward() + lagu.
  motor2Backward('Motor 2 mundur 5000 step', true),

  /// Jeda sesudah M2 mundur — setelah ini siklus berikutnya dimulai.
  waitAfterM2('Tunggu antar gerakan', false);

  const MiniaturSegment(this.label, this.isMotion);

  final String label;

  /// True saat motor bergerak → lampu indikator berkedip + lagu diputar.
  final bool isMotion;
}

/// Urutan & durasi segmen SEBELUM siklus berulang pertama.
const List<(MiniaturSegment, int)> miniaturStartSchedule = [
  (MiniaturSegment.standbyWait, miniaturInitialWaitMs),
];

/// Urutan & durasi satu siklus penuh (berulang terus-menerus).
const List<(MiniaturSegment, int)> miniaturCycleSchedule = [
  (MiniaturSegment.bothForward, miniaturMotionMs),
  (MiniaturSegment.waitAfterBoth, miniaturWaitBetweenMs),
  (MiniaturSegment.motor1Backward, miniaturMotionMs),
  (MiniaturSegment.waitAfterM1, miniaturWaitBetweenMs),
  (MiniaturSegment.motor2Backward, miniaturMotionMs),
  (MiniaturSegment.waitAfterM2, miniaturWaitBetweenMs),
];

// =====================================================
// TOPIK & PERINTAH (kontrak untuk firmware mendatang)
// =====================================================

/// Topik MQTT miniatur, dibaca dari `.env` (MQTT_TOPIC_MINIATUR_*).
/// Konvensi prefix `client3` — lanjutan feeder (`client2`).
class MiniaturTopics {
  MiniaturTopics._();

  /// Perintah dari aplikasi (app = master).
  static String get set => Env.topicMiniaturSet;

  /// Status dari perangkat (device = slave, belum ada di firmware kini).
  static String get status => Env.topicMiniaturStatus;
}

/// Pembangun payload perintah JSON untuk topik [MiniaturTopics.set].
///
/// Perintah yang dipahami firmware mendatang — spesifikasi lengkap
/// di `implementasi_IoT.md`:
///
/// | `cmd` | field | makna di firmware (rencana) |
/// |---|---|---|
/// | `cycle_start` | — | lanjutkan siklus otomatis (setelah dijeda) |
/// | `cycle_stop` | — | jeda siklus setelah gerakan aktif selesai |
/// | `home_all` | — | homing kedua motor |
/// | `home` | `motor: 1\|2` | homing satu motor |
/// | `move` | `motor: 1\|2`, `dir: fwd\|back` | gerakan manual 5000 step |
/// | `track` | `track: 1..3` | ganti lagu gerakan |
/// | `volume` | `volume: 0..30` | volume DFPlayer |
/// | `lamp` | `lamp: 1\|2`, `on: bool` | lampu indikator manual |
abstract final class MiniaturCommands {
  static Map<String, Object?> cycleStart() => {'cmd': 'cycle_start'};

  static Map<String, Object?> cycleStop() => {'cmd': 'cycle_stop'};

  static Map<String, Object?> homeAll() => {'cmd': 'home_all'};

  static Map<String, Object?> homeMotor(int motor) =>
      {'cmd': 'home', 'motor': motor};

  static Map<String, Object?> moveMotor(int motor, bool forward) =>
      {'cmd': 'move', 'motor': motor, 'dir': forward ? 'fwd' : 'back'};

  static Map<String, Object?> setTrack(int track) =>
      {'cmd': 'track', 'track': track};

  static Map<String, Object?> setVolume(int volume) =>
      {'cmd': 'volume', 'volume': volume};

  static Map<String, Object?> setLamp(int lamp, bool on) =>
      {'cmd': 'lamp', 'lamp': lamp, 'on': on};

  /// Encode ringkas untuk tampil di log UI.
  static String describe(Map<String, Object?> cmd) => jsonEncode(cmd);
}

/// Status yang akan di-publish firmware mendatang ke
/// [MiniaturTopics.status] — di-parse dari JSON
/// `{"state":"idle|homing|moving|error","motor1":"...","motor2":"...",
/// "track":2,"volume":20,"lamp1":true,"lamp2":false,"ts":1710000000}`.
///
/// Semua field nullable: payload parsial dari firmware versi mana pun
/// tetap bisa dicatat tanpa error.
@immutable
class MiniaturDeviceStatus {
  const MiniaturDeviceStatus({
    this.state,
    this.motor1,
    this.motor2,
    this.track,
    this.volume,
    this.lamp1,
    this.lamp2,
    this.timestampMs,
  });

  /// `idle` | `homing` | `moving` | `error`.
  final String? state;
  final String? motor1;
  final String? motor2;
  final int? track;
  final int? volume;
  final bool? lamp1;
  final bool? lamp2;
  final int? timestampMs;

  factory MiniaturDeviceStatus.fromJson(Object? json) {
    if (json is! Map) return const MiniaturDeviceStatus();
    bool? optBool(Object? v) => v is bool ? v : null;
    int? optInt(Object? v) => v is num ? v.toInt() : null;
    String? optStr(Object? v) => v is String && v.isNotEmpty ? v : null;
    return MiniaturDeviceStatus(
      state: optStr(json['state']),
      motor1: optStr(json['motor1']),
      motor2: optStr(json['motor2']),
      track: optInt(json['track']),
      volume: optInt(json['volume']),
      lamp1: optBool(json['lamp1']),
      lamp2: optBool(json['lamp2']),
      timestampMs: optInt(json['ts']),
    );
  }
}

// =====================================================
// SNAPSHOT ESTIMASI KONDISI PERANGKAT
// =====================================================

/// Hasil estimasi kondisi perangkat pada satu titik waktu.
@immutable
class MiniaturSnapshot {
  const MiniaturSnapshot({
    required this.powerOnAt,
    required this.cycleBaseAt,
    required this.segment,
    required this.segmentElapsedMs,
    required this.segmentDurationMs,
    required this.cycleIndex,
    required this.lamp1On,
    required this.lamp2On,
    required this.motor1State,
    required this.motor2State,
    required this.stepsDone,
  });

  /// Waktu perangkat diperkirakan menyala (kalibrasi tahap 1), atau null
  /// bila belum pernah dikalibrasi.
  final DateTime? powerOnAt;

  /// Baseline siklus (homing dianggap selesai tepat sebelum waktu ini),
  /// atau null bila baru dikalibrasi tahap 1.
  final DateTime? cycleBaseAt;

  /// Fase perangkat saat ini.
  final MiniaturSegment segment;

  /// Berapa ms fase ini sudah berjalan.
  final int segmentElapsedMs;

  /// Durasi fase menurut firmware. 0 untuk `homing` (durasi tak diketahui).
  final int segmentDurationMs;

  /// Pengulangan siklus ke-n dalam `loop()`, mulai 1. 0 saat belum masuk
  /// siklus pertama (homing/standby).
  final int cycleIndex;

  /// Estimasi lampu indikator (LAMP1/LAMP3 firmware) — aktif saat fase
  /// bergerak, berkedip tiap [miniaturLampIntervalMs].
  final bool lamp1On;
  final bool lamp2On;

  /// `"maju"`, `"mundur"`, atau `"idle"` (estimasi arah motor).
  final String motor1State;
  final String motor2State;

  /// Estimasi step yang sudah ditempuh motor yang sedang berjalan
  /// (profil trapesium). 0 saat tidak ada motor bergerak.
  final int stepsDone;

  /// Sisa waktu fase (ms); 0 untuk homing.
  int get segmentRemainingMs =>
      segmentDurationMs <= 0 ? 0 : segmentDurationMs - segmentElapsedMs;

  /// Progress fase 0.0–1.0 (homing selalu 0.0).
  double get segmentProgress {
    if (segmentDurationMs <= 0) return 0;
    return (segmentElapsedMs / segmentDurationMs).clamp(0.0, 1.0);
  }
}

// =====================================================
// SIMULATOR
// =====================================================

/// Replikasi state machine `main.cpp` sebagai estimator murni. Ia
/// menghitung di fase mana perangkat berada berdasarkan dua titik
/// kalibrasi:
///
/// 1. [markPowerOn] — pengguna menandai saat perangkat baru menyala/reset;
/// 2. [markHomingFinished] — pengguna menandai motor sudah di posisi nol.
///
/// Kalibrasi tahap 2 memakai asumsi firmware: setelah homing selesai,
/// perangkat memainkan lagu 004 lalu menunggu [miniaturInitialWaitMs]
/// sebelum memasuki siklus pertama.
class MiniaturSimulator extends ChangeNotifier {
  MiniaturSimulator({
    int initialTrack = 1,
    this.trackLoader,
    this.trackSaver,
  }) : _track = initialTrack;

  /// Memuat pilihan lagu tersimpan aplikasi (pengganti NVS firmware).
  final Future<int?> Function()? trackLoader;

  /// Dipanggil setiap pilihan lagu berubah (pengganti
  /// `preferences.putUChar`).
  final void Function(int track)? trackSaver;

  DateTime? _powerOnAt;
  DateTime? _cycleBaseAt;
  int _track;

  DateTime? get powerOnAt => _powerOnAt;
  DateTime? get cycleBaseAt => _cycleBaseAt;

  /// True bila setidaknya kalibrasi tahap 1 sudah dilakukan.
  bool get hasPowerOn => _powerOnAt != null;

  /// Track yang aplikasinya perangkat diputar (1–3).
  ///
  /// PENTING: ini **asumsi** — pilihan lagu hanya bisa diubah lewat tombol
  /// UP/DOWN fisik dan tidak ada telemetria, sehingga pengguna perlu
  /// menyinkronkan nilai ini saat mengganti lagu di perangkat.
  int get track => _track;

  /// Memuat pilihan lagu tersimpan (dipanggil sekali saat halaman dibuka;
  /// pengganti `loadMotionTrack()` firmware).
  Future<void> loadTrack() async {
    final loader = trackLoader;
    if (loader == null) return;
    final raw = await loader();
    if (raw != null && raw >= miniaturMinTrack && raw <= miniaturMaxTrack) {
      _track = raw;
      notifyListeners();
    }
  }

  /// True bila [loadTrack] sudah pernah selesai.
  bool trackLoaded = false;

  /// Tombol UP app — setara `changeMotionTrack(true)`: 1→2→3→1.
  void trackUp() => changeTrack(next: true);

  /// Tombol DOWN app — setara `changeMotionTrack(false)`: 1→3→2→1.
  void trackDown() => changeTrack(next: false);

  /// Port `changeMotionTrack()` + `saveMotionTrack()`.
  void changeTrack({required bool next}) {
    var track = _track;
    if (next) {
      track++;
      if (track > miniaturMaxTrack) track = miniaturMinTrack;
    } else {
      if (track <= miniaturMinTrack) {
        track = miniaturMaxTrack;
      } else {
        track--;
      }
    }
    if (track == _track) return;
    _track = track;
    trackSaver?.call(track);
    notifyListeners();
  }

  /// Kalibrasi tahap 1: perangkat baru dinyalakan (atau direset).
  void markPowerOn([DateTime? when]) {
    _powerOnAt = when ?? DateTime.now();
    _cycleBaseAt = null;
    notifyListeners();
  }

  /// Kalibrasi tahap 2: motor sudah berada di posisi nol (homing selesai).
  /// Baseline dimundurkan [miniaturInitialWaitMs] karena firmware sudah
  /// melewati lagu standby jeda itu sebelum siklus pertama.
  void markHomingFinished([DateTime? when]) {
    final at = when ?? DateTime.now();
    _powerOnAt ??= at;
    _cycleBaseAt = at.subtract(const Duration(milliseconds: miniaturInitialWaitMs));
    notifyListeners();
  }

  /// Mengatur ulang kalibrasi (misal pengguna salah menandai fase).
  void resetCalibration() {
    _powerOnAt = null;
    _cycleBaseAt = null;
    notifyListeners();
  }

  /// True bila sudah dikalibrasi tahap 2 — estimasi fase bisa berjalan.
  bool get hasCycleBase => _cycleBaseAt != null;

  /// Estimasi kondisi perangkat pada [when]. Aman dipanggil sebelum
  /// [markPowerOn]: hasilnya fase homing (durasi 0).
  MiniaturSnapshot snapshotAt(DateTime when) {
    final powerOn = _powerOnAt;
    final cycleBase = _cycleBaseAt;

    if (cycleBase != null && !when.isBefore(cycleBase)) {
      return _cyclicSnapshot(powerOn, cycleBase, when);
    }
    return _homingSnapshot(powerOn, cycleBase);
  }

  /// Fase homing — durasi tidak diketahui sampai pengguna mengkalibrasi
  /// tahap 2 (lampu mati, kedua motor idle).
  MiniaturSnapshot _homingSnapshot(DateTime? powerOn, DateTime? cycleBase) {
    return MiniaturSnapshot(
      powerOnAt: powerOn,
      cycleBaseAt: cycleBase,
      segment: MiniaturSegment.homing,
      segmentElapsedMs: 0,
      segmentDurationMs: 0,
      cycleIndex: 0,
      lamp1On: false,
      lamp2On: false,
      motor1State: 'idle',
      motor2State: 'idle',
      stepsDone: 0,
    );
  }

  MiniaturSnapshot _cyclicSnapshot(
    DateTime? powerOn,
    DateTime cycleBase,
    DateTime when,
  ) {
    final since = when.difference(cycleBase).inMilliseconds;

    // Fase awal: standby lagu 004 sebelum siklus pertama.
    var consumed = 0;
    for (final (segment, durationMs) in miniaturStartSchedule) {
      if (since < consumed + durationMs) {
        return _snapshot(segment, since - consumed, durationMs, 0);
      }
      consumed += durationMs;
    }

    // Siklus berulang tanpa akhir.
    final cycleT = since - consumed;
    final cycleIndex = (cycleT ~/ miniaturCycleMs) + 1;
    var inCycle = cycleT % miniaturCycleMs;

    for (final (segment, durationMs) in miniaturCycleSchedule) {
      if (inCycle < durationMs) {
        return _snapshot(segment, inCycle, durationMs, cycleIndex);
      }
      inCycle -= durationMs;
    }
    assert(false, 'Tidak mungkin: durasi tidak mencukupi satu siklus');
    return _homingSnapshot(powerOn, cycleBase);
  }

  MiniaturSnapshot _snapshot(
    MiniaturSegment segment,
    int elapsedMs,
    int durationMs,
    int cycleIndex,
  ) {
    final motion = segment.isMotion;
    return MiniaturSnapshot(
      powerOnAt: _powerOnAt,
      cycleBaseAt: _cycleBaseAt,
      segment: segment,
      segmentElapsedMs: elapsedMs,
      segmentDurationMs: durationMs,
      cycleIndex: cycleIndex,
      lamp1On: motion ? lampOnAt(elapsedMs) : false,
      lamp2On: motion ? lampOnAt(elapsedMs) : false,
      motor1State: motorState(segment, motor: 1),
      motor2State: motorState(segment, motor: 2),
      stepsDone: motion ? stepsDoneInMotion(elapsedMs) : 0,
    );
  }

  /// Estimasi arah motor pada suatu fase (`"maju"`/`"mundur"`/`"idle"`).
  static String motorState(MiniaturSegment segment, {required int motor}) {
    switch (segment) {
      case MiniaturSegment.bothForward:
        return 'maju';
      case MiniaturSegment.motor1Backward:
        return motor == 1 ? 'mundur' : 'idle';
      case MiniaturSegment.motor2Backward:
        return motor == 2 ? 'mundur' : 'idle';
      case MiniaturSegment.homing:
      case MiniaturSegment.standbyWait:
      case MiniaturSegment.waitAfterBoth:
      case MiniaturSegment.waitAfterM1:
      case MiniaturSegment.waitAfterM2:
        return 'idle';
    }
  }

  /// Estimasi kedip lampu (firmware menyetel LOW di awal dan toggle setiap
  /// 1 s → detik pertama OFF, berikutnya ON–OFF–ON…).
  static bool lampOnAt(int elapsedMs) {
    if (elapsedMs < miniaturLampIntervalMs) return false;
    return (elapsedMs ~/ miniaturLampIntervalMs).isOdd;
  }

  /// Step yang sudah ditempuh dalam window [miniaturMotionMs] dengan
  /// profil trapesium (a = [miniaturAccelStepsPerS2], vmax =
  /// [miniaturMaxSpeedStepsPerS]):
  ///
  /// - 0–1 s   : s = 0.5·a·t²                → 100 step pada 1 s
  /// - 1–25 s  : s = 100 + vmax·(t−1)        → 4900 step pada 25 s
  /// - 25–26 s : s = 4900 + vmax·r − 0.5·a·r², r = t−25  → 5000 step
  static int stepsDoneInMotion(int elapsedMs) {
    if (elapsedMs <= 0) return 0;
    if (elapsedMs >= miniaturMotionMs) return miniaturStepsPerCycle;
    final t = elapsedMs / 1000.0;
    double steps;
    if (t < 1.0) {
      steps = 0.5 * miniaturAccelStepsPerS2 * t * t;
    } else if (t <= 25.0) {
      steps = 100.0 + miniaturMaxSpeedStepsPerS * (t - 1.0);
    } else {
      final r = (t - 25.0).clamp(0.0, 1.0);
      steps = 4900.0 +
          miniaturMaxSpeedStepsPerS * r -
          0.5 * miniaturAccelStepsPerS2 * r * r;
    }
    return math.max(0, steps.round());
  }
}

// =====================================================
// CONTROLLER (simulator + log + status live)
// =====================================================

/// Controller UI miniatur — menggabungkan simulator Overwatch, log
/// perintah/status MQTT, dan status perangkat bila tersedia dari firmware.
class MiniaturController extends ChangeNotifier {
  MiniaturController({MiniaturSimulator? simulator})
      : simulator = simulator ??
            MiniaturSimulator(
              trackLoader: loadTrackPersisted,
              trackSaver: saveTrackPersisted,
            );

  static final MiniaturController instance = MiniaturController();

  /// Simulator estimasi — port perilaku otomatis firmware.
  final MiniaturSimulator simulator;

  /// Status perangkat terakhir dari topik status (null bila firmware
  /// belum pernah mengirim).
  MiniaturDeviceStatus? lastDeviceStatus;

  /// Log ringkas aktivitas — entri terbaru di index 0.
  final List<String> commandLog = [];

  static const int _maxLog = 30;

  /// Entri log untuk ditampilkan di UI (maks 6).
  List<String> get recentLog =>
      commandLog.take(6).toList(growable: false);

  /// Mencatat satu baris pada log (dipanggil page setelah publish).
  void log(String line) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    commandLog.insert(0, '$stamp  $line');
    if (commandLog.length > _maxLog) {
      commandLog.removeRange(_maxLog, commandLog.length);
    }
    notifyListeners();
  }

  /// Callback MQTT: memantau pesan masuk pada topik miniatur.
  void handleMqttMessage(String topic, String payload) {
    if (topic != MiniaturTopics.status) return;
    Object? doc;
    try {
      doc = jsonDecode(payload);
    } on FormatException {
      debugPrint('[Miniatur] Payload status bukan JSON: $payload');
      return;
    }
    lastDeviceStatus = MiniaturDeviceStatus.fromJson(doc);
    log('<- status: $payload');
  }

  @override
  void dispose() {
    simulator.dispose();
    super.dispose();
  }
}

/// Memuat pilihan lagu tersimpan di SharedPreferences (pengganti NVS).
Future<int?> loadTrackPersisted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('miniatur_track');
}

/// Menyimpan pilihan lagu ke SharedPreferences (fire-and-forget).
void saveTrackPersisted(int track) {
  unawaited(
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('miniatur_track', track);
    }),
  );
}
