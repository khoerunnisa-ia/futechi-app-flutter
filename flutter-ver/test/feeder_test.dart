import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futechi/config/env.dart';
import 'package:futechi/data/feeder.dart';
import 'package:futechi/data/feeder_link.dart';
import 'package:futechi/screens/feeding_page.dart';

class FakeHardware implements FeederHardware {
  int now = 0;
  final Map<int, bool> pins = {};
  final Map<int, bool> inputs = {};
  final Map<int, List<bool>> sampleQueue = {};
  final List<(int, bool)> writes = [];
  final List<int> delays = [];

  bool pin(int p) => pins[p] ?? false;

  void press(int p) => inputs[p] = false;
  void release(int p) => inputs[p] = true;

  @override
  int millis() => now;

  @override
  void digitalWrite(int pin, bool high) {
    pins[pin] = high;
    writes.add((pin, high));
  }

  @override
  bool digitalRead(int pin) {
    final queue = sampleQueue[pin];
    if (queue != null && queue.isNotEmpty) return queue.removeAt(0);
    return inputs[pin] ?? true;
  }

  @override
  Future<void> delay(int ms) async {
    delays.add(ms);
    now += ms;
  }
}

class FakeLink extends FeederLink {
  FakeLink({this.succeed = true, this.failAttemptsBeforeSuccess = 0});

  bool succeed;
  int failAttemptsBeforeSuccess;
  int publishCount = 0;
  int schedulePublishCount = 0;
  int connectCallCount = 0;
  int disconnectCallCount = 0;
  List<FeederSchedule>? lastPublishedSchedules;
  FeederLinkState _state = FeederLinkState.disconnected;
  String? _customError;

  void setState(FeederLinkState s, [String? error]) {
    _state = s;
    _customError = error;
    notifyListeners();
  }

  @override
  FeederLinkState get state => _state;

  @override
  String? get lastError => _customError ?? (succeed ? null : 'offline');

  @override
  Future<bool> connect() async {
    connectCallCount++;
    if (failAttemptsBeforeSuccess > 0) {
      failAttemptsBeforeSuccess--;
      _state = FeederLinkState.error;
      _customError = 'Koneksi sementara gagal';
      notifyListeners();
      return false;
    }
    _state = succeed ? FeederLinkState.connected : FeederLinkState.error;
    if (!succeed) _customError = 'offline';
    notifyListeners();
    return succeed;
  }

  @override
  Future<bool> reconnect() async {
    await disconnect();
    return connect();
  }

  @override
  Future<bool> publishFeedNow() async {
    if (!await connect()) return false;
    publishCount++;
    return true;
  }

  @override
  Future<bool> publishSchedule(List<FeederSchedule> schedules) async {
    if (!await connect()) return false;
    schedulePublishCount++;
    lastPublishedSchedules = schedules;
    return true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    _state = FeederLinkState.disconnected;
    notifyListeners();
  }
}

/// [FeederTopics] membaca `.env` yang tidak dimuat di lingkungan test,
/// jadi ia selalu jatuh ke nilai default yang sama dengan firmware.
void expectDefaultTopics() {
  expect(FeederTopics.setPakan, 'client2/set/pakan');
  expect(FeederTopics.setJadwal, 'client2/set/jadwal');
  expect(FeederTopics.status, 'client2/status');
}

/// Wednesday 2026-10-14 10:00 → dayOfTheWeek 3 (Rabu).
DateTime wednesdayAt(int hour, int minute) => DateTime(2026, 10, 14, hour, minute);

void main() {
  late FakeHardware hw;
  late DateTime now;
  late List<(String, String)> published;
  late FeederController c;

  FeederController build({int runMode = 2}) {
    final controller = FeederController(
      hardware: hw,
      clock: () => now,
      autoTick: false,
      onPublish: (t, p) => published.add((t, p)),
    );
    controller.setRunMode(runMode);
    return controller;
  }

  void advance(int ms) => hw.now += ms;

  setUp(() {
    hw = FakeHardware();
    now = wednesdayAt(10, 0);
    published = [];
    c = build();
  });

  group('helpers', () {
    test('topik MQTT default sama dengan firmware', () {
      expectDefaultTopics();
    });

    test('isValidTime accepts HHMM in range', () {
      expect(isValidTime('0000'), isTrue);
      expect(isValidTime('2359'), isTrue);
      expect(isValidTime('0730'), isTrue);
    });

    test('isValidTime rejects bad length, range and non-digits', () {
      expect(isValidTime('730'), isFalse);
      expect(isValidTime('07300'), isFalse);
      expect(isValidTime('2400'), isFalse);
      expect(isValidTime('1260'), isFalse);
      expect(isValidTime('ab12'), isFalse);
      expect(isValidTime(''), isFalse);
    });

    test('formatTimeDisplay formats partial keypad input', () {
      expect(formatTimeDisplay(''), '');
      expect(formatTimeDisplay('0'), '0');
      expect(formatTimeDisplay('07'), '07');
      expect(formatTimeDisplay('073'), '07:3');
      expect(formatTimeDisplay('0730'), '07:30');
    });

    test('arduinoToInt parses leading integer like String.toInt()', () {
      expect(arduinoToInt('07'), 7);
      expect(arduinoToInt('7:'), 7);
      expect(arduinoToInt('ab'), 0);
      expect(arduinoToInt(' -3x'), -3);
    });

    test('restoreConveyorTime keeps 1..120, otherwise 5', () {
      expect(restoreConveyorTime(1), 1);
      expect(restoreConveyorTime(120), 120);
      expect(restoreConveyorTime(0), 5);
      expect(restoreConveyorTime(121), 5);
      expect(restoreConveyorTime(255), 5);
    });

    test('restoreRunMode keeps 1 or 2, otherwise 2', () {
      expect(restoreRunMode(1), 1);
      expect(restoreRunMode(2), 2);
      expect(restoreRunMode(0), 2);
      expect(restoreRunMode(255), 2);
    });

    test('dayOfTheWeek uses 0 = Minggu', () {
      expect(dayOfTheWeek(DateTime(2026, 10, 18)), 0); // Sunday
      expect(daysOfTheWeek[dayOfTheWeek(wednesdayAt(0, 0))], 'Rabu');
    });
  });

  group('FeederLinkConfig', () {
    test('memakai nilai default `.env` saat tanpa --dart-define', () {
      // `.env` tidak dimuat di lingkungan test → seluruh field jatuh ke default.
      final config = FeederLinkConfig.fromEnvironment();
      expect(config.host, 'mqtt.stiatech.my.id');
      expect(config.port, 1883);
      expect(config.username, '');
      expect(config.password, '');
      expect(config.clientId, isNull);
      expect(config.hasCredentials, isFalse);
    });

    test('nilai eksplisit dipakai apa adanya', () {
      const config = FeederLinkConfig(
        host: '10.0.0.5',
        port: 8883,
        username: 'app',
        password: 'rahasia',
        clientId: 'flutter-feeder-unique-01',
      );
      expect(config.port, 8883);
      expect(config.hasCredentials, isTrue);
      expect(config.clientId, 'flutter-feeder-unique-01');
    });

    test('description memuat host/port/clientId tanpa membocorkan password', () {
      const config = FeederLinkConfig(
        host: 'mqtt.stiatech.my.id',
        username: 'mqttuser',
        password: 'Robotika',
        clientId: 'flutter-feeder-unique-01',
      );
      expect(config.description, contains('mqtt.stiatech.my.id:1883'));
      expect(config.description, contains('mqttuser'));
      expect(config.description, contains('flutter-feeder-unique-01'));
      expect(config.description, isNot(contains('Robotika')));
      expect(config.toString(), isNot(contains('Robotika')));
    });

    test('clientId null → description menandai ID acak', () {
      const config = FeederLinkConfig(host: 'broker.local');
      expect(config.description, contains('<acak>'));
    });
  });

  group('Env', () {
    test('belum dimuat → seluruh getter memakai default', () {
      expect(Env.loaded, isFalse);
      expect(Env.mqttHost, 'mqtt.stiatech.my.id');
      expect(Env.mqttPort, 1883);
      expect(Env.mqttUser, '');
      expect(Env.mqttPass, '');
      expect(Env.mqttClientId, isNull);
      expect(Env.topicFeed, 'client2/set/pakan');
      expect(Env.topicSchedule, 'client2/set/jadwal');
      expect(Env.topicStatus, 'client2/status');
      expect(Env.chatBaseUrl, 'http://localhost:3000');
    });

    test('getInt/getBool menangani nilai kosong dan tidak valid', () {
      expect(Env.getInt('MQTT_PORT', 1883), 1883);
      expect(Env.getBool('MQTT_TLS', false), isFalse);
    });
  });

  group('settings', () {
    test('defaults: mode 2, conveyor 5 s, status READY', () {
      final fresh = FeederController(hardware: hw, autoTick: false);
      expect(fresh.runMode, 2);
      expect(fresh.conveyorTime, 5);
      expect(fresh.status, FeederStatus.ready);
      expect(fresh.client2Status, '-');
    });

    test('setConveyorTime accepts 1..120 only', () {
      expect(c.setConveyorTime(0), isFalse);
      expect(c.setConveyorTime(121), isFalse);
      expect(c.conveyorTime, 5);
      expect(c.setConveyorTime(1), isTrue);
      expect(c.setConveyorTime(120), isTrue);
      expect(c.conveyorTime, 120);
    });

    test('loadConveyorTime and loadRunMode apply EEPROM defaults', () {
      c.loadConveyorTime(200);
      expect(c.conveyorTime, 5);
      c.loadRunMode(9);
      expect(c.runMode, 2);
      c.loadRunMode(1);
      expect(c.runMode, 1);
    });

    test('toggleRunMode cycles 1 ↔ 2 and setRunMode validates', () {
      c.setRunMode(1);
      c.toggleRunMode();
      expect(c.runMode, 2);
      c.toggleRunMode();
      expect(c.runMode, 1);
      expect(c.setRunMode(3), isFalse);
      expect(c.runMode, 1);
    });
  });

  group('triggerFeed / feedNow', () {
    test('triggerFeed beeps 200 ms then waits 1 s', () async {
      final future = c.triggerFeed('MANUAL');
      expect(c.feeding, isTrue);
      await future;
      expect(c.feeding, isFalse);
      expect(hw.delays, [200, 1000]);
      expect(hw.writes.where((w) => w.$1 == FeederPins.buzzer).toList(),
          [(FeederPins.buzzer, true), (FeederPins.buzzer, false)]);
      expect(published, isEmpty);
    });

    test('triggerFeed is ignored while already feeding', () async {
      final first = c.triggerFeed('MANUAL');
      await c.triggerFeed('MANUAL');
      await first;
      expect(hw.delays, [200, 1000]);
    });

    test('feedNow beeps then starts the system and publishes RUN once', () async {
      expect(await c.feedNow(), isTrue);
      expect(c.systemRunning, isTrue);
      expect(c.status, FeederStatus.run);
      expect(published, [(FeederTopics.status, '{"pakan":"RUN"}')]);
    });

    test('feedNow returns false while feeding or already running', () async {
      final first = c.feedNow();
      expect(await c.feedNow(), isFalse);
      expect(await first, isTrue);
      expect(await c.feedNow(), isFalse);
    });
  });

  group('startSystem', () {
    test('mode 2 starts both motors and conveyor, DIR flips to kiri first', () {
      expect(c.startSystem(), isTrue);
      expect(c.motor1Running, isTrue);
      expect(c.motor2Running, isTrue);
      expect(c.motor1Dir, isFalse);
      expect(c.motor2Dir, isFalse);
      expect(c.conveyorRunning, isTrue);
      expect(hw.pin(FeederPins.relay1), isTrue);

      c.tick();
      expect(hw.pin(FeederPins.relay2), isTrue);
      expect(hw.pin(FeederPins.relay3), isFalse);
      expect(hw.pin(FeederPins.relay4), isTrue);
      expect(hw.pin(FeederPins.relay5), isFalse);
    });

    test('mode 1 starts motor 1 only', () {
      c = build(runMode: 1);
      c.startSystem();
      c.tick();
      expect(c.motor1Running, isTrue);
      expect(c.motor2Running, isFalse);
      expect(hw.pin(FeederPins.relay4), isFalse);
      expect(hw.writes.contains((FeederPins.relay4, true)), isFalse);
    });

    test('second start while running is ignored', () {
      c.startSystem();
      expect(c.startSystem(), isFalse);
      expect(c.motor1Dir, isFalse);
    });

    test('direction alternates on every run', () {
      c.startSystem();
      advance(1000);
      hw.press(FeederPins.limit1);
      hw.press(FeederPins.limit3);
      c.tick();
      expect(c.systemRunning, isFalse);

      hw.release(FeederPins.limit1);
      hw.release(FeederPins.limit3);
      c.startSystem();
      expect(c.motor1Dir, isTrue);
      expect(c.motor2Dir, isTrue);
    });
  });

  group('limits and completion', () {
    test('limits are ignored during the first 1000 ms', () {
      c.startSystem();
      hw.press(FeederPins.limit1);
      advance(999);
      c.tick();
      expect(c.motor1Running, isTrue);
      expect(hw.pin(FeederPins.relay2), isTrue);

      advance(1);
      c.tick();
      expect(c.motor1Running, isFalse);
      expect(hw.pin(FeederPins.relay2), isFalse);
    });

    test('either limit switch stops its motor', () {
      c.startSystem();
      advance(1000);
      hw.press(FeederPins.limit2);
      hw.press(FeederPins.limit4);
      c.tick();
      expect(c.motor1Running, isFalse);
      expect(c.motor2Running, isFalse);
    });

    test('readLimit needs at least 3 of 5 LOW samples', () {
      hw.sampleQueue[FeederPins.limit1] = [false, true, false, true, false];
      expect(c.readLimit(FeederPins.limit1), isTrue);
      hw.sampleQueue[FeederPins.limit1] = [false, true, true, true, false];
      expect(c.readLimit(FeederPins.limit1), isFalse);
    });

    test('mode 2: READY when motor 2 finishes last', () {
      c.startSystem();
      advance(1000);
      hw.press(FeederPins.limit1);
      c.tick();
      expect(c.systemRunning, isTrue);
      expect(c.status, FeederStatus.run);

      hw.press(FeederPins.limit3);
      c.tick();
      expect(c.systemRunning, isFalse);
      expect(c.status, FeederStatus.ready);
    });

    test('mode 2: READY when motor 1 finishes last', () {
      c.startSystem();
      advance(1000);
      hw.press(FeederPins.limit3);
      c.tick();
      expect(c.status, FeederStatus.run);

      hw.press(FeederPins.limit1);
      c.tick();
      expect(c.status, FeederStatus.ready);
      expect(published.last, (FeederTopics.status, '{"pakan":"READY"}'));
    });

    test('mode 1: READY after motor 1 stops', () {
      c = build(runMode: 1);
      c.startSystem();
      advance(1000);
      hw.press(FeederPins.limit1);
      c.tick();
      expect(c.status, FeederStatus.ready);
    });

    test('mode 1 idle loop keeps READY', () {
      c = build(runMode: 1);
      c.tick();
      c.tick();
      expect(c.status, FeederStatus.ready);
      expect(published, isEmpty);
    });

    test('switching to mode 1 mid-run stops motor 2 once', () {
      c.startSystem();
      c.tick();
      c.setRunMode(1);
      c.tick();
      expect(c.motor2Running, isFalse);
      expect(hw.pin(FeederPins.relay4), isFalse);
      expect(c.systemRunning, isTrue);

      final relay4Writes =
          hw.writes.where((w) => w == (FeederPins.relay4, false)).length;
      c.tick();
      expect(hw.writes.where((w) => w == (FeederPins.relay4, false)).length,
          relay4Writes);
    });
  });

  group('conveyor', () {
    test('stops when conveyorTime seconds elapsed', () {
      c.setConveyorTime(3);
      c.startSystem();
      advance(2999);
      c.tick();
      expect(c.conveyorRunning, isTrue);
      expect(c.conveyorRemainingMs, 1);

      advance(1);
      c.tick();
      expect(c.conveyorRunning, isFalse);
      expect(hw.pin(FeederPins.relay1), isFalse);
      expect(c.conveyorRemainingMs, 0);
    });

    test('keeps running after motors finish until its timer ends', () {
      c.startSystem();
      advance(1000);
      hw.press(FeederPins.limit1);
      hw.press(FeederPins.limit3);
      c.tick();
      expect(c.status, FeederStatus.ready);
      expect(c.conveyorRunning, isTrue);
      advance(4000);
      c.tick();
      expect(c.conveyorRunning, isFalse);
    });
  });

  group('DIR relay timeout', () {
    test('DIR turns off only after more than 2000 ms stopped', () {
      c.startSystem();
      advance(1000);
      hw.press(FeederPins.limit1);
      hw.press(FeederPins.limit3);
      c.tick();
      expect(c.motor1DirActive, isTrue);

      advance(2000);
      c.tick();
      expect(c.motor1DirActive, isTrue);
      expect(c.motor2DirActive, isTrue);

      advance(1);
      c.tick();
      expect(c.motor1DirActive, isFalse);
      expect(c.motor2DirActive, isFalse);
      expect(hw.pin(FeederPins.relay3), isFalse);
      expect(hw.pin(FeederPins.relay5), isFalse);
      expect(c.isActive, isTrue); // conveyor still running
    });

    test('motor 2 DIR times out after switching to mode 1', () {
      c.startSystem();
      c.tick();
      c.setRunMode(1);
      c.tick();
      advance(2001);
      c.tick();
      expect(c.motor2DirActive, isFalse);
    });
  });

  group('buttons', () {
    test('STOP button stops everything with status STOP', () {
      c.startSystem();
      c.tick();
      hw.press(FeederPins.buttonStop);
      c.tick();
      expect(c.status, FeederStatus.stop);
      expect(c.systemRunning, isFalse);
      expect(c.motor1Running, isFalse);
      expect(c.motor2Running, isFalse);
      expect(c.conveyorRunning, isFalse);
      expect(hw.pin(FeederPins.relay1), isFalse);
      expect(hw.pin(FeederPins.relay2), isFalse);
      expect(hw.pin(FeederPins.relay4), isFalse);
    });

    test('START button triggers on falling edge only', () {
      hw.press(FeederPins.buttonStart);
      c.tick();
      expect(c.systemRunning, isTrue);
      final dir = c.motor1Dir;

      c.stopAllMotor();
      c.tick(); // still held: no new edge
      expect(c.systemRunning, isFalse);

      hw.release(FeederPins.buttonStart);
      c.tick();
      hw.press(FeederPins.buttonStart);
      c.tick();
      expect(c.systemRunning, isTrue);
      expect(c.motor1Dir, !dir);
    });

    test('start after STOP goes back to RUN', () {
      c.startSystem();
      c.stopAllMotor();
      expect(c.status, FeederStatus.stop);
      c.startSystem();
      expect(c.status, FeederStatus.run);
    });
  });

  group('status publish', () {
    test('publishes only when status changes', () {
      c.setSystemStatus(FeederStatus.ready);
      expect(published, isEmpty);
      c.setSystemStatus(FeederStatus.stop);
      c.setSystemStatus(FeederStatus.stop);
      expect(published, [(FeederTopics.status, '{"pakan":"STOP"}')]);
    });
  });

  group('MQTT messages', () {
    test('set/pakan {"run":1} runs feedNow', () async {
      c.handleMqttMessage(FeederTopics.setPakan, '{"run":1}');
      expect(c.feeding, isTrue);
      await pumpEventQueue();
      expect(c.systemRunning, isTrue);
    });

    test('set/pakan ignores other values and invalid JSON', () async {
      for (final payload in ['{"run":0}', '{"run":"1"}', '{"run":true}', 'oops', '[1]']) {
        c.handleMqttMessage(FeederTopics.setPakan, payload);
      }
      await pumpEventQueue();
      expect(c.feeding, isFalse);
      expect(c.systemRunning, isFalse);
    });

    test('client2/status updates device status', () {
      c.handleMqttMessage(FeederTopics.status, '{"pakan":"RUN"}');
      expect(c.client2Status, 'RUN');
      c.handleMqttMessage(FeederTopics.status, 'broken');
      expect(c.client2Status, 'RUN');
      c.handleMqttMessage(FeederTopics.status, '{"pakan":1}');
      expect(c.client2Status, '-');
      c.handleMqttMessage(FeederTopics.status, '{}');
      expect(c.client2Status, '-');
    });

    test('set/jadwal replaces schedules', () {
      c.handleMqttMessage(FeederTopics.setJadwal,
          '[{"on":"07:00","days":["Senin","Rabu"]},{"on":"16:30","days":["Minggu"]}]');
      expect(c.scheduleChanged, isTrue);
      expect(c.schedules.length, 2);
      expect(c.schedules[0].time, '07:00');
      expect(c.schedules[0].days, ['Senin', 'Rabu']);
    });

    test('set/jadwal ignores invalid JSON and non-array roots', () {
      c.addSchedule('0700', [true]);
      c.handleMqttMessage(FeederTopics.setJadwal, '{"on":"08:00"}');
      c.handleMqttMessage(FeederTopics.setJadwal, 'not json');
      expect(c.schedules.single.time, '07:00');
      expect(c.scheduleChanged, isFalse);
    });

    test('set/jadwal caps at 10 schedules and 7 days', () {
      final many = [
        for (var i = 0; i < 12; i++) {'on': '0$i:00', 'days': ['Senin']},
      ];
      c.handleMqttMessage(FeederTopics.setJadwal, jsonEncode(many));
      expect(c.schedules.length, maxSchedule);

      c.handleMqttMessage(FeederTopics.setJadwal,
          jsonEncode([{'on': '07:00', 'days': [...daysOfTheWeek, 'Senin', 'Selasa']}]));
      expect(c.schedules.single.days.length, maxScheduleDays);
    });

    test('set/jadwal keeps malformed entries as empty schedules', () {
      c.handleMqttMessage(FeederTopics.setJadwal, '[5,{"on":7,"days":"Senin"}]');
      expect(c.schedules.length, 2);
      expect(c.schedules[0].time, '');
      expect(c.schedules[1].time, '');
      expect(c.schedules[1].days, isEmpty);
    });
  });

  group('schedules', () {
    test('addSchedule stores HH:MM with checked days in week order', () {
      final selected = List.filled(7, false)
        ..[5] = true
        ..[1] = true;
      expect(c.addSchedule('0730', selected), isTrue);
      expect(c.schedules.single.time, '07:30');
      expect(c.schedules.single.days, ['Senin', 'Jumat']);
    });

    test('addSchedule rejects invalid time, no days, or full list', () {
      expect(c.addSchedule('2460', [true]), isFalse);
      expect(c.addSchedule('0700', List.filled(7, false)), isFalse);
      for (var i = 0; i < maxSchedule; i++) {
        expect(c.addSchedule('0700', [true]), isTrue);
      }
      expect(c.addSchedule('0800', [true]), isFalse);
    });

    test('deleteSchedule removes by index and validates range', () {
      c.addSchedule('0700', [true]);
      c.addSchedule('0800', [true]);
      expect(c.deleteSchedule(2), isFalse);
      expect(c.deleteSchedule(0), isTrue);
      expect(c.schedules.single.time, '08:00');
    });

    test('schedulesToJson round-trips through restoreSchedules', () {
      c.addSchedule('0700', [false, true, false, true]);
      final json = c.schedulesToJson();
      expect(json, '[{"on":"07:00","days":["Senin","Rabu"]}]');

      final other = build();
      other.restoreSchedules(json);
      expect(other.scheduleSignature(), c.scheduleSignature());
      expect(c.scheduleSignature(), '07:00SeninRabu');
    });

    test('restoreSchedules: empty/invalid keeps, non-array clears', () {
      c.addSchedule('0700', [true]);
      c.restoreSchedules('');
      c.restoreSchedules(null);
      c.restoreSchedules('{broken');
      expect(c.schedules.length, 1);
      c.restoreSchedules('{"on":"07:00"}');
      expect(c.schedules, isEmpty);
    });
  });

  group('getNextSchedule', () {
    void load(List<Map<String, dynamic>> s) =>
        c.handleMqttMessage(FeederTopics.setJadwal, jsonEncode(s));

    test('none when no schedules', () {
      final next = c.getNextSchedule();
      expect(next.exists, isFalse);
      expect(next.day, '-');
      expect(next.time, '-');
      expect(next.diff, -1);
    });

    test('later today', () {
      load([{'on': '10:30', 'days': ['Rabu']}]);
      final next = c.getNextSchedule();
      expect(next.day, 'Rabu');
      expect(next.diff, 30);
    });

    test('earlier today or same minute wraps to next week', () {
      load([{'on': '09:00', 'days': ['Rabu']}]);
      expect(c.getNextSchedule().diff, 7 * 1440 - 60);
      load([{'on': '10:00', 'days': ['Rabu']}]);
      expect(c.getNextSchedule().diff, 7 * 1440);
    });

    test('other days, including earlier in the week', () {
      load([{'on': '08:00', 'days': ['Kamis']}]);
      expect(c.getNextSchedule().diff, 1440 - 120);
      load([{'on': '10:00', 'days': ['Senin']}]);
      expect(c.getNextSchedule().diff, 5 * 1440);
    });

    test('picks the nearest and skips unknown days and short times', () {
      load([
        {'on': '7:00', 'days': ['Rabu']},
        {'on': '12:00', 'days': ['Wednesday', 'Jumat']},
        {'on': '11:00', 'days': ['Kamis', 'Rabu']},
      ]);
      final next = c.getNextSchedule();
      expect(next.time, '11:00');
      expect(next.day, 'Rabu');
      expect(next.diff, 60);
    });
  });

  test('getTodaySchedules lists today only, up to maxResult', () {
    c.handleMqttMessage(FeederTopics.setJadwal, jsonEncode([
      {'on': '07:00', 'days': ['Rabu', 'Rabu']},
      {'on': '08:00', 'days': ['Kamis']},
      {'on': '16:00', 'days': ['Senin', 'Rabu']},
    ]));
    expect(c.getTodaySchedules(), ['07:00', '16:00']);
    expect(c.getTodaySchedules(1), ['07:00']);
  });

  group('checkSchedule', () {
    setUp(() {
      c.handleMqttMessage(FeederTopics.setJadwal,
          jsonEncode([{'on': '10:00', 'days': ['Rabu', 'Kamis']}]));
    });

    test('starts once at the matching day and minute', () {
      c.checkSchedule();
      expect(c.systemRunning, isTrue);
      expect(c.lastTrigger, 'Rabu10:00');
      expect(hw.delays, isEmpty); // no buzzer on scheduled runs

      c.stopAllMotor();
      c.checkSchedule();
      expect(c.systemRunning, isFalse);
    });

    test('does not start on other days or minutes', () {
      now = wednesdayAt(10, 1);
      c.checkSchedule();
      now = DateTime(2026, 10, 16, 10, 0); // Jumat
      c.checkSchedule();
      expect(c.systemRunning, isFalse);
    });

    test('next matching day triggers again', () {
      c.checkSchedule();
      c.stopAllMotor();
      now = DateTime(2026, 10, 15, 10, 0); // Kamis
      c.checkSchedule();
      expect(c.systemRunning, isTrue);
      expect(c.lastTrigger, 'Kamis10:00');
    });
  });

  group('simulated hardware', () {
    test('full manual feed cycle returns to READY with everything off', () async {
      var clock = 0;
      final sim = SimulatedFeederHardware(
        motor1TravelMs: 3000,
        motor2TravelMs: 4000,
        millisClock: () => clock,
        delayFn: (ms) async => clock += ms,
      );
      final controller = FeederController(
          hardware: sim, clock: () => now, autoTick: false);

      expect(await controller.feedNow(), isTrue);
      var guard = 0;
      while (controller.isActive && guard++ < 1000) {
        clock += 50;
        controller.tick();
      }

      expect(controller.status, FeederStatus.ready);
      expect(controller.isActive, isFalse);
      expect(sim.motor1Position, 0);
      expect(sim.motor2Position, 0);
      for (final p in [FeederPins.relay1, FeederPins.relay2, FeederPins.relay3,
          FeederPins.relay4, FeederPins.relay5]) {
        expect(sim.pin(p), isFalse, reason: 'pin $p');
      }

      // Next run travels back the other way.
      controller.startSystem();
      guard = 0;
      while (controller.systemRunning && guard++ < 1000) {
        clock += 50;
        controller.tick();
      }
      expect(sim.motor1Position, 3000);
      expect(sim.motor2Position, 4000);
    });
  });

  group('FeedingPage "Beri Pakan Sekarang"', () {
    Future<void> pumpPage(WidgetTester tester, FeederController controller,
        FeederLink link) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: FeedingPage(controller: controller, link: link)),
      ));
    }

    Finder feedButton() => find.widgetWithText(FilledButton, 'Beri Pakan Sekarang');

    testWidgets('sends MQTT command and runs the logic', (tester) async {
      final link = FakeLink();
      await pumpPage(tester, c, link);
      expect(find.text('READY'), findsOneWidget);

      await tester.tap(feedButton());
      await tester.pump();
      await tester.pump();

      expect(link.publishCount, 1);
      expect(c.systemRunning, isTrue);
      expect(find.text('RUN'), findsOneWidget);
      expect(find.text('Perintah pakan dikirim ke feeder'), findsOneWidget);
      expect(find.text('Terhubung'), findsOneWidget);
      expect(tester.widget<FilledButton>(feedButton()).onPressed, isNull);

      await tester.tap(feedButton(), warnIfMissed: false);
      await tester.pump();
      expect(link.publishCount, 1);
    });

    testWidgets('still runs the simulation when the feeder is offline',
        (tester) async {
      final link = FakeLink(succeed: false);
      await pumpPage(tester, c, link);
      await tester.pump(const Duration(seconds: 10));

      await tester.tap(feedButton());
      await tester.pump();
      await tester.pump();

      expect(link.publishCount, 0);
      expect(c.systemRunning, isTrue);
      expect(find.text('Feeder tidak terhubung, menjalankan simulasi saja'),
          findsOneWidget);
      expect(find.text('Gagal terhubung'), findsOneWidget);
    });

    testWidgets('shows device status from client2/status', (tester) async {
      final link = FakeLink();
      await pumpPage(tester, c, link);
      link.onMessage!(FeederTopics.status, '{"pakan":"STOP"}');
      await tester.pump();
      expect(find.text('STOP'), findsOneWidget);
    });

    testWidgets('shows "Hubungkan ke Hardware" button when disconnected/offline and hides when connected',
        (tester) async {
      final link = FakeLink(succeed: false);
      await pumpPage(tester, c, link);
      await tester.pump(const Duration(seconds: 10));

      final connectBtn = find.byKey(const ValueKey('button_connect_hardware'));
      expect(connectBtn, findsOneWidget);
      expect(find.text('Hubungkan ke Hardware'), findsOneWidget);
      expect(find.text('offline'), findsOneWidget);

      // Now link becomes available and user taps the connect button
      link.succeed = true;
      await tester.tap(connectBtn);
      await tester.pump();

      expect(link.state, FeederLinkState.connected);
      expect(find.text('Terhubung'), findsOneWidget);
      expect(find.byKey(const ValueKey('button_connect_hardware')), findsNothing);
    });
  });

  group('FeederLink operations', () {
    test('publishSchedule connects and sends schedules', () async {
      final link = FakeLink();
      final schedules = [
        FeederSchedule(time: '07:00', days: ['Senin', 'Rabu']),
        FeederSchedule(time: '16:30', days: ['Jumat']),
      ];

      final ok = await link.publishSchedule(schedules);
      expect(ok, isTrue);
      expect(link.schedulePublishCount, 1);
      expect(link.lastPublishedSchedules, schedules);
      expect(link.state, FeederLinkState.connected);
    });

    test('publishSchedule returns false if connection fails', () async {
      final link = FakeLink(succeed: false);
      final schedules = [
        FeederSchedule(time: '08:00', days: ['Minggu']),
      ];

      final ok = await link.publishSchedule(schedules);
      expect(ok, isFalse);
      expect(link.schedulePublishCount, 0);
    });

    test('reconnect disconnects old connection and connects new', () async {
      final link = FakeLink();
      await link.connect();
      expect(link.connectCallCount, 1);

      final ok = await link.reconnect();
      expect(ok, isTrue);
      expect(link.disconnectCallCount, 1);
      expect(link.connectCallCount, 2);
      expect(link.state, FeederLinkState.connected);
    });

    test('autoConnect skips when already connected', () async {
      final link = FakeLink();
      await link.connect();
      expect(link.connectCallCount, 1);

      final ok = await link.autoConnect();
      expect(ok, isTrue);
      expect(link.connectCallCount, 1); // Not called again
    });

    test('autoConnect retries on failure up to maxRetries', () async {
      final link = FakeLink(succeed: false);
      final ok = await link.autoConnect(
        maxRetries: 3,
        retryDelay: Duration.zero,
      );
      expect(ok, isFalse);
      expect(link.connectCallCount, 3);
    });

    test('autoConnect succeeds if retry attempt passes', () async {
      final link = FakeLink(succeed: true, failAttemptsBeforeSuccess: 2);
      final ok = await link.autoConnect(
        maxRetries: 4,
        retryDelay: Duration.zero,
      );
      expect(ok, isTrue);
      expect(link.connectCallCount, 3);
      expect(link.state, FeederLinkState.connected);
    });
  });
}
