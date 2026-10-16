/// Konfigurasi runtime dari asset `.env`.
///
/// `.env` di-deklarasikan di `pubspec.yaml` dan dimuat sekali lewat
/// [Env.load] di `main.dart`. Semua nilai yang bergantung pada lingkungan
/// (kredensial broker MQTT, topik, URL backend AI) dibaca dari sini — jangan
/// pernah menaruh kredensial langsung di kode.
///
/// File `.env` tidak ikut ter-commit; template tersedia di `.env.example`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Status pemuatan `.env`.
enum EnvStatus {
  /// [Env.load] belum pernah dipanggil.
  notLoaded,

  /// `.env` berhasil dibaca.
  loaded,

  /// `.env` tidak ada atau tidak bisa dibaca — seluruh getter memakai default.
  failed,
}

class Env {
  Env._();

  /// Nama file konfigurasi (asset, bukan path filesystem).
  static const fileName = '.env';

  static EnvStatus _status = EnvStatus.notLoaded;
  static String? _loadError;

  static EnvStatus get status => _status;

  /// True setelah [load] berhasil.
  static bool get loaded => _status == EnvStatus.loaded;

  /// Pesan kesalahan bila [status] == [EnvStatus.failed].
  static String? get loadError => _loadError;

  /// Memuat `.env` sekali. Aman dipanggil berkali-kali.
  ///
  /// Gagal memuat bukan kondisi fatal: seluruh pembacaan di bawah punya nilai
  /// default, sehingga aplikasi tetap bisa dijalankan (mode simulasi tanpa
  /// broker). Kesalahan dicatat lewat [debugPrint] supaya terlihat di konsol
  /// `flutter run` maupun build profile/release.
  static Future<void> load() async {
    if (_status == EnvStatus.loaded) return;
    try {
      await dotenv.load(fileName: fileName);
      _status = EnvStatus.loaded;
      _loadError = null;
      debugPrint('[Env] $fileName dimuat — ${mqttSummary()}');
    } catch (error) {
      _status = EnvStatus.failed;
      _loadError = '$error';
      debugPrint(
        '[Env] GAGAL memuat $fileName: $error\n'
        '        → seluruh konfigurasi memakai nilai default. '
        'Pastikan file .env ada di root flutter-ver (salin dari .env.example).',
      );
    }
  }

  /// Memaksa baca ulang `.env` (dipakai tombol "Hubungkan" setelah file
  /// `.env` diperbaiki tanpa me-restart aplikasi).
  static Future<bool> reload() async {
    _status = EnvStatus.notLoaded;
    dotenv.clean();
    await load();
    return _status == EnvStatus.loaded;
  }

  /// Ringkasan konfigurasi MQTT untuk log — tidak pernah memuat password.
  static String mqttSummary() {
    final user = mqttUser.isEmpty ? '-' : mqttUser;
    final id = mqttClientId ?? '<acak>';
    final pass = mqttPass.isEmpty ? 'KOSONG' : 'terisi(${mqttPass.length})';
    return 'host=$mqttHost:$mqttPort user=$user pass=$pass clientId=$id '
        'topik[feed=$topicFeed status=$topicStatus]';
  }

  /// Nilai mentah, atau null bila kosong/tidak ada.
  static String? maybe(String key) {
    final value = _status == EnvStatus.loaded ? dotenv.maybeGet(key) : null;
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Nilai dengan fallback. String kosong di `.env` dianggap "tidak diisi".
  static String getOr(String key, String fallback) => maybe(key) ?? fallback;

  static int getInt(String key, int fallback) =>
      int.tryParse(maybe(key) ?? '') ?? fallback;

  static bool getBool(String key, bool fallback) {
    final value = maybe(key)?.toLowerCase();
    if (value == null) return fallback;
    return value == '1' || value == 'true' || value == 'yes' || value == 'on';
  }

  // ===================== MQTT =====================

  /// Broker feeder. Harus sama dengan `mqtt_server` di firmware.
  static String get mqttHost => getOr('MQTT_HOST', 'mqtt.stiatech.my.id');

  /// 1883 = TCP polos, 8883 = TLS (belum didukung implementasi saat ini).
  static int get mqttPort => getInt('MQTT_PORT', 1883);

  static String get mqttUser => maybe('MQTT_USER') ?? '';

  static String get mqttPass => maybe('MQTT_PASS') ?? '';

  /// Client ID tetap dari `.env`; null berarti pakai ID acak
  /// `futechi-app-<8 hex>` (lihat [MqttFeederLink]). Jangan pernah memakai
  /// `ESP32_FEEDER` — broker akan memutus koneksi perangkat.
  static String? get mqttClientId => maybe('MQTT_CLIENT_ID');

  // ===================== Topik =====================

  static String get topicStatus => getOr('MQTT_TOPIC_STATUS', 'client2/status');

  static String get topicFeed => getOr('MQTT_TOPIC_FEED', 'client2/set/pakan');

  static String get topicSchedule =>
      getOr('MQTT_TOPIC_SCHEDULE', 'client2/set/jadwal');

  // ===================== Backend AI =====================

  /// Base URL deployment react-js yang menyajikan `POST /api/chat`.
  static String get chatBaseUrl =>
      getOr('FUTECHI_CHAT_URL', 'http://localhost:3000');

  // ===================== Direct LLM API =====================

  /// API Key untuk direct cloud LLM (OpenRouter, Groq, dll.).
  /// Bila kosong, [ChatClient] fallback ke backend proxy [chatBaseUrl].
  static String? get llmApiKey => maybe('LLM_API_KEY');

  /// Endpoint API OpenAI-compatible. Default: OpenRouter.
  static String get llmBaseUrl =>
      getOr('LLM_BASE_URL', 'https://openrouter.ai/api/v1/chat/completions');

  /// Model ID yang digunakan. Default: gemini-2.0-flash via OpenRouter.
  static String get llmModel =>
      getOr('LLM_MODEL', 'google/gemini-2.0-flash-001');

  // ===================== CCTV Tapo RTSP =====================

  /// URL RTSP stream utama kamera Tapo (Full HD).
  /// Format: `rtsp://user:pass@ip:554/stream1`.
  /// Kosong berarti widget menampilkan thumbnail statis (mode demo).
  static String? get cctvRtspUrl => maybe('CCTV_RTSP_URL');

  /// URL RTSP sub-stream (360p/720p, ringan untuk pemantauan)
  static String? get cctvRtspSubstreamUrl => maybe('CCTV_RTSP_SUBSTREAM_URL');

  /// True jika stream otomatis dimulai saat widget pertama tampil.
  static bool get cctvAutoPlay => getBool('CCTV_AUTO_PLAY', false);
}