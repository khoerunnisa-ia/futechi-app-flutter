import 'package:flutter_test/flutter_test.dart';

import 'package:futechi/data/miniatur.dart';

void main() {
  // Firmware `miniaturFutechi` TIDAK punya MQTT; test di sini mengunci
  // matematika simulator Overwatch + kontrak MQTT masa depan.

  group('Matematika gerakan (profil trapesium 5000 step)', () {
    test('0 step di awal dan tepat 5000 di akhir window', () {
      expect(MiniaturSimulator.stepsDoneInMotion(0), 0);
      expect(MiniaturSimulator.stepsDoneInMotion(-100), 0);
      expect(MiniaturSimulator.stepsDoneInMotion(26000), 5000);
      expect(MiniaturSimulator.stepsDoneInMotion(60000), 5000);
    });

    test('akselerasi 1 detik menghabiskan tepat 100 step', () {
      expect(MiniaturSimulator.stepsDoneInMotion(1000), 100);
      // t = 0.5 s: s = 0.5 * 200 * 0.5^2 = 25
      expect(MiniaturSimulator.stepsDoneInMotion(500), 25);
    });

    test('kecepatan konstan 200 step/s di tengah gerakan', () {
      // t = 13 s: 100 + 200 * 12 = 2500 (tepat setengah jalan).
      expect(MiniaturSimulator.stepsDoneInMotion(13000), 2500);
      // t = 3 s: 100 + 200 * 2 = 500.
      expect(MiniaturSimulator.stepsDoneInMotion(3000), 500);
    });

    test('deselerasi menuju 0 step/s di akhir window', () {
      // t = 25.5 s: 4900 + 200*0.5 - 100*0.25 = 4975.
      expect(MiniaturSimulator.stepsDoneInMotion(25500), 4975);
    });
  });

  group('Estimasi kedip lampu (toggle 1 s, detik pertama OFF)', () {
    test('pola ON-OFF sesuai firmware', () {
      expect(MiniaturSimulator.lampOnAt(0), isFalse);
      expect(MiniaturSimulator.lampOnAt(999), isFalse);
      expect(MiniaturSimulator.lampOnAt(1000), isTrue);
      expect(MiniaturSimulator.lampOnAt(2000), isFalse);
      expect(MiniaturSimulator.lampOnAt(3000), isTrue);
    });
  });

  group('Simulator fase', () {
    test('tanpa kalibrasi → fase homing', () {
      final sim = MiniaturSimulator();
      final s = sim.snapshotAt(DateTime.now());
      expect(s.segment, MiniaturSegment.homing);
      expect(s.segmentDurationMs, 0);
      expect(s.cycleIndex, 0);
      expect(sim.hasPowerOn, isFalse);
      expect(sim.hasCycleBase, isFalse);
    });

    test('kalibrasi penuh → standby 3 detik lalu masuk siklus', () {
      final powerOn = DateTime(2026, 1, 1, 12, 0, 0);
      final sim = MiniaturSimulator();
      sim.markPowerOn(powerOn);
      // Pengguna menekan "motor sudah di nol" 61 detik setelah power on.
      sim.markHomingFinished(powerOn.add(const Duration(milliseconds: 61000)));
      expect(sim.hasCycleBase, isTrue);

      final t = sim.cycleBaseAt!;
      // Baseline dimundurkan 3 dtk (INITIAL_WAIT), jadi 1 dtk setelahnya
      // masih berada di fase standby.
      final sStandby =
          sim.snapshotAt(t.add(const Duration(milliseconds: 1000)));
      expect(sStandby.segment, MiniaturSegment.standbyWait);
      expect(sStandby.segmentElapsedMs, 1000);
      expect(sStandby.cycleIndex, 0);
      expect(sStandby.lamp1On, isFalse);
      expect(sStandby.motor1State, 'idle');

      // 3 detik standby selesai → siklus 1 dimulai: maju bersama.
      final sStart =
          sim.snapshotAt(t.add(const Duration(milliseconds: 3000)));
      expect(sStart.segment, MiniaturSegment.bothForward);
      expect(sStart.segmentElapsedMs, 0);
      expect(sStart.cycleIndex, 1);
    });

    test('siklus: maju bersama → jeda → M1 mundur → jeda → M2 mundur', () {
      final base = DateTime(2026, 1, 1, 12, 0, 0);
      final sim = MiniaturSimulator();
      sim.markPowerOn(base);
      sim.markHomingFinished(base);
      final t = sim.cycleBaseAt!;

      // 3000 + 13000 = 16 s: setengah jalan maju bersama.
      final sMid =
          sim.snapshotAt(t.add(const Duration(milliseconds: 16000)));
      expect(sMid.segment, MiniaturSegment.bothForward);
      expect(sMid.motor1State, 'maju');
      expect(sMid.motor2State, 'maju');
      expect(sMid.stepsDone, 2500);
      expect(sMid.lamp1On, isTrue); // 16 s → indeks kedip ganjil → ON.

      // 29000+3000 = 32 s: fase jeda sesudah maju bersama.
      final sWait =
          sim.snapshotAt(t.add(const Duration(milliseconds: 32000)));
      expect(sWait.segment, MiniaturSegment.waitAfterBoth);
      expect(sWait.segmentElapsedMs, 3000);
      expect(sWait.motor1State, 'idle');
      expect(sWait.stepsDone, 0);

      // 3000 + 26000 + 30000 = 59000, +1 ms → fase motor 1 mundur baru
      // dimulai (window [56000, 82000) ms relatif siklus = 168000 ms).
      final sM1 =
          sim.snapshotAt(t.add(const Duration(milliseconds: 59001)));
      expect(sM1.segment, MiniaturSegment.motor1Backward);
      expect(sM1.motor1State, 'mundur');
      expect(sM1.motor2State, 'idle');
      expect(sM1.segmentElapsedMs, 1);

      // 3000 + 26000 + 30000 + 26000 = 85000 (+15 ms) → jeda sesudah
      // motor 1 mundur: window [82000, 112000) relatif siklus.
      final sWaitM1 =
          sim.snapshotAt(t.add(const Duration(milliseconds: 85015)));
      expect(sWaitM1.segment, MiniaturSegment.waitAfterM1);
      expect(sWaitM1.motor1State, 'idle');

      // 1 siklus penuh (168 s) + 3 s standby: kembali ke maju bersama.
      final sNext =
          sim.snapshotAt(t.add(const Duration(milliseconds: 3000 + 168000)));
      expect(sNext.segment, MiniaturSegment.bothForward);
      expect(sNext.segmentElapsedMs, 0);
      expect(sNext.cycleIndex, 2);
    });

    test('pengulangan ke-3 tetap disinkronkan ke fase siklus berulang', () {
      final base = DateTime(2026, 1, 1, 12, 0, 0);
      final sim = MiniaturSimulator();
      sim.markPowerOn(base);
      sim.markHomingFinished(base);
      final t = sim.cycleBaseAt!;
      final s = sim.snapshotAt(t.add(
          const Duration(milliseconds: 3000 + miniaturCycleMs * 2 + 5000)));
      expect(s.cycleIndex, 3);
      expect(s.segment, MiniaturSegment.bothForward);
      expect(s.segmentElapsedMs, 5000);
      expect(MiniaturSimulator.stepsDoneInMotion(5000), s.stepsDone);
    });
  });

  group('Pilihan lagu (asumsi app mengikuti tombol fisik)', () {
    test('UP/DOWN wrap sesuai firmware: 1→2→3→1 dan 1→3', () {
      final saved = <int>[];
      final sim = MiniaturSimulator(trackSaver: saved.add, initialTrack: 1);
      sim.trackUp();
      sim.trackUp();
      expect(sim.track, 3);
      sim.trackUp();
      expect(sim.track, 1); // melewati max → wrap ke min.
      expect(saved, [2, 3, 1]);

      sim.trackDown();
      expect(sim.track, 3); // di bawah min → wrap ke max.
      expect(saved.last, 3);
    });

    test('nilai di luar 1..3 bila dimuat langsung tidak diterapkan', () {
      final sim =
          MiniaturSimulator(trackLoader: () async => 9, initialTrack: 1);
      return sim.loadTrack().then((_) => expect(sim.track, 1));
    });
  });

  group('Kontrak MQTT masa depan', () {
    test('perintah di-encode jadi JSON minimal', () {
      expect(
        MiniaturCommands.describe(MiniaturCommands.cycleStart()),
        '{"cmd":"cycle_start"}',
      );
      expect(
        MiniaturCommands.describe(MiniaturCommands.moveMotor(1, false)),
        '{"cmd":"move","motor":1,"dir":"back"}',
      );
      expect(
        MiniaturCommands.describe(MiniaturCommands.setLamp(2, true)),
        '{"cmd":"lamp","lamp":2,"on":true}',
      );
    });

    test('status firmware diparse dengan field nullable', () {
      final status = MiniaturDeviceStatus.fromJson({
        'state': 'moving',
        'motor1': 'maju',
        'track': 2,
        'volume': 20,
        'lamp1': true,
        'ts': 1710000000,
      });
      expect(status.state, 'moving');
      expect(status.motor1, 'maju');
      expect(status.motor2, isNull);
      expect(status.track, 2);
      expect(status.volume, 20);
      expect(status.lamp1, isTrue);
      expect(status.lamp2, isNull);

      // Payload aneh / bukan map → status kosong, tidak crash.
      final empty = MiniaturDeviceStatus.fromJson('salah');
      expect(empty.state, isNull);
      expect(empty.track, isNull);
    });
  });
}
