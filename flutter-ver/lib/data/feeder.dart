/// Port of pakan-sc/pakanAyam_v2/src/main.cpp (feeding, schedule and
/// settings logic).
///
/// TFT drawing, keypad menu, WiFi/NTP and EEPROM I/O stay on the ESP32.
/// Pin access goes through [FeederHardware] so the same logic runs against
/// [SimulatedFeederHardware] in the app and fakes in tests.
///
/// Differences from the firmware (status fixes):
/// - Status returns to READY once every active motor has stopped at its
///   limit, in both run modes and regardless of which motor finishes last.
/// - Mode 1 no longer forces STOP every loop; motor 2 is switched off once,
///   so its DIR relay timeout still fires.
/// - [FeederController.triggerFeed] no longer publishes RUN/STOP around the
///   buzzer; [FeederController.startSystem] publishes RUN.
/// - Emergency stop also clears the conveyor running flag.
/// - Default run mode is 2 at boot and when the stored value is invalid.
/// - A schedule keeps at most 7 days and times must be digits only.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/env.dart';

class FeederPins {
  static const buzzer = 17;
  static const buttonStart = 13;
  static const buttonStop = 14;

  static const limit1 = 35;
  static const limit2 = 34;
  static const limit3 = 39;
  static const limit4 = 36;

  /// EN conveyor
  static const relay1 = 32;

  /// EN motor 1
  static const relay2 = 33;

  /// DIR motor 1
  static const relay3 = 25;

  /// EN motor 2
  static const relay4 = 26;

  /// DIR motor 2
  static const relay5 = 27;
}

/// Topik MQTT, dibaca dari `.env` (MQTT_TOPIC_*) dengan fallback ke nilai
/// yang sama dengan firmware `pakanAyam_v2/src/main.cpp`.
class FeederTopics {
  static String get setPakan => Env.topicFeed;
  static String get setJadwal => Env.topicSchedule;
  static String get status => Env.topicStatus;
}

const int limitIgnoreTimeMs = 1000;
const int dirTimeoutMs = 2000;
const int maxSchedule = 10;
const int maxScheduleDays = 7;
const int defaultConveyorTime = 5;
const int maxConveyorTime = 120;
const int defaultRunMode = 2;

/// Index 0 = Minggu, matching RTClib `dayOfTheWeek()`.
const List<String> daysOfTheWeek = [
  'Minggu',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

/// RTClib day index (0 = Minggu) for a Dart [DateTime].
int dayOfTheWeek(DateTime t) => t.weekday % 7;

enum FeederStatus {
  ready('READY'),
  run('RUN'),
  stop('STOP');

  const FeederStatus(this.label);
  final String label;
}

/// Pin and timing access. `true` = HIGH. Inputs are active LOW (pull-up).
abstract class FeederHardware {
  int millis();
  void digitalWrite(int pin, bool high);
  bool digitalRead(int pin);
  Future<void> delay(int ms);
}

class FeederSchedule {
  FeederSchedule({required this.time, List<String> days = const []})
      : days = List.unmodifiable(days);

  /// "HH:MM"
  final String time;
  final List<String> days;

  Map<String, dynamic> toJson() => {'on': time, 'days': days};
}

class NextSchedule {
  const NextSchedule({required this.day, required this.time, required this.diff});

  static const none = NextSchedule(day: '-', time: '-', diff: -1);

  final String day;
  final String time;

  /// Minutes until the schedule, -1 if none.
  final int diff;

  bool get exists => diff >= 0;
}

/// Arduino `String.toInt()` (atol): leading integer, 0 if none.
int arduinoToInt(String s) {
  final match = RegExp(r'^\s*([+-]?\d+)').firstMatch(s);
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Keypad input "HHMM".
bool isValidTime(String t) {
  if (t.length != 4) return false;
  if (!RegExp(r'^\d{4}$').hasMatch(t)) return false;

  final hour = arduinoToInt(t.substring(0, 2));
  final minute = arduinoToInt(t.substring(2, 4));

  if (hour < 0 || hour > 23) return false;
  if (minute < 0 || minute > 59) return false;
  return true;
}

String formatTimeDisplay(String t) {
  if (t.isEmpty) return '';
  if (t.length <= 2) return t;
  if (t.length == 3) return '${t.substring(0, 2)}:${t.substring(2)}';
  return '${t.substring(0, 2)}:${t.substring(2, 4)}';
}

/// EEPROM timer value: 1..120, otherwise default 5.
int restoreConveyorTime(int raw) =>
    raw > 0 && raw <= maxConveyorTime ? raw : defaultConveyorTime;

/// EEPROM run mode value: 1 or 2, otherwise default 2.
int restoreRunMode(int raw) => raw == 1 || raw == 2 ? raw : defaultRunMode;

/// Parses a schedule JSON array (`[{"on":"HH:MM","days":[...]}]`).
List<FeederSchedule> parseScheduleArray(List<dynamic> arr) {
  final result = <FeederSchedule>[];
  for (final item in arr) {
    if (result.length >= maxSchedule) break;
    final obj = item is Map ? item : const <String, dynamic>{};
    final on = obj['on'];
    final days = <String>[];
    final rawDays = obj['days'];
    if (rawDays is List) {
      for (final d in rawDays) {
        if (days.length >= maxScheduleDays) break;
        days.add(d is String ? d : jsonEncode(d));
      }
    }
    result.add(FeederSchedule(time: on is String ? on : '', days: days));
  }
  return result;
}

class FeederController extends ChangeNotifier {
  FeederController({
    required this.hardware,
    DateTime Function()? clock,
    this.autoTick = true,
    this.tickInterval = const Duration(milliseconds: 50),
    this.onPublish,
  }) : _clock = clock ?? DateTime.now;

  static final FeederController instance =
      FeederController(hardware: SimulatedFeederHardware());

  final FeederHardware hardware;
  final DateTime Function() _clock;

  /// Runs [tick] on a timer while the system is active.
  final bool autoTick;
  final Duration tickInterval;

  /// Port of `client.publish` for status changes.
  void Function(String topic, String payload)? onPublish;

  bool _motor1DirActive = false;
  bool _motor1Running = false;
  bool _motor1Dir = true; // true = kanan, false = kiri
  int _motor1StartTime = 0;
  int _motor1StopTime = 0;

  bool _motor2DirActive = false;
  bool _motor2Running = false;
  bool _motor2Dir = true;
  int _motor2StartTime = 0;
  int _motor2StopTime = 0;

  int _conveyorStartTime = 0;
  bool _conveyorRunning = false;

  bool _systemRunning = false;
  bool _feeding = false;

  bool _lastButtonStart = true;
  bool _lastButtonStop = true;

  FeederStatus _status = FeederStatus.ready;
  int _runMode = defaultRunMode;
  int _conveyorTime = defaultConveyorTime;
  String _client2Status = '-';

  List<FeederSchedule> _schedules = [];
  String _lastTrigger = '';
  bool _scheduleChanged = false;

  Timer? _ticker;

  bool get motor1DirActive => _motor1DirActive;
  bool get motor1Running => _motor1Running;
  bool get motor1Dir => _motor1Dir;
  bool get motor2DirActive => _motor2DirActive;
  bool get motor2Running => _motor2Running;
  bool get motor2Dir => _motor2Dir;
  bool get conveyorRunning => _conveyorRunning;
  bool get systemRunning => _systemRunning;
  bool get feeding => _feeding;
  FeederStatus get status => _status;
  int get runMode => _runMode;
  int get conveyorTime => _conveyorTime;
  String get client2Status => _client2Status;
  List<FeederSchedule> get schedules => List.unmodifiable(_schedules);
  String get lastTrigger => _lastTrigger;
  bool get scheduleChanged => _scheduleChanged;

  /// True while anything still needs [tick] (feeding, motors, conveyor,
  /// or a DIR relay waiting for its timeout).
  bool get isActive =>
      _feeding ||
      _systemRunning ||
      _conveyorRunning ||
      _motor1DirActive ||
      _motor2DirActive;

  int get conveyorRemainingMs {
    if (!_conveyorRunning) return 0;
    final elapsed = hardware.millis() - _conveyorStartTime;
    return math.max(0, _conveyorTime * 1000 - elapsed);
  }

  // ================= SETTINGS =================

  /// Keypad timer save: accepts 1..120 seconds only.
  bool setConveyorTime(int seconds) {
    if (seconds <= 0 || seconds > maxConveyorTime) return false;
    _conveyorTime = seconds;
    notifyListeners();
    return true;
  }

  void loadConveyorTime(int raw) {
    _conveyorTime = restoreConveyorTime(raw);
    notifyListeners();
  }

  /// Keypad A/B in MENU_MODE_MOTOR: 1 ↔ 2.
  void toggleRunMode() {
    _runMode = _runMode >= 2 ? 1 : _runMode + 1;
    notifyListeners();
  }

  bool setRunMode(int mode) {
    if (mode != 1 && mode != 2) return false;
    _runMode = mode;
    notifyListeners();
    return true;
  }

  void loadRunMode(int raw) {
    _runMode = restoreRunMode(raw);
    notifyListeners();
  }

  // ================= FEED =================

  /// Buzzer 200 ms then 1 s pause; ignored while already feeding.
  Future<void> triggerFeed(String mode) async {
    if (_feeding) return;
    _feeding = true;
    _ensureTicker();
    notifyListeners();

    hardware.digitalWrite(FeederPins.buzzer, true);
    await hardware.delay(200);
    hardware.digitalWrite(FeederPins.buzzer, false);
    await hardware.delay(1000);

    _feeding = false;
    notifyListeners();
  }

  /// MQTT `client2/set/pakan {"run":1}`: triggerFeed("MANUAL") then
  /// startSystem(). Returns false if a feed is already in progress or the
  /// system was already running.
  Future<bool> feedNow() async {
    if (_feeding) return false;
    await triggerFeed('MANUAL');
    return startSystem();
  }

  // ================= MOTOR & CONVEYOR CONTROL =================

  void _motor1(bool en, bool dir) {
    if (en) {
      hardware.digitalWrite(FeederPins.relay3, dir);
      hardware.digitalWrite(FeederPins.relay2, true);
      _motor1DirActive = true;
    } else {
      hardware.digitalWrite(FeederPins.relay2, false);
      _motor1StopTime = hardware.millis();
    }
  }

  void _motor2(bool en, bool dir) {
    if (en) {
      hardware.digitalWrite(FeederPins.relay5, dir);
      hardware.digitalWrite(FeederPins.relay4, true);
      _motor2DirActive = true;
    } else {
      hardware.digitalWrite(FeederPins.relay4, false);
      _motor2StopTime = hardware.millis();
    }
  }

  void _conveyor(bool en) => hardware.digitalWrite(FeederPins.relay1, en);

  /// Publishes only when the status changes.
  void setSystemStatus(FeederStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    onPublish?.call(FeederTopics.status, '{"pakan":"${newStatus.label}"}');
    notifyListeners();
  }

  void stopAllMotor() {
    _motor1(false, _motor1Dir);
    _motor2(false, _motor2Dir);
    _conveyor(false);

    _motor1Running = false;
    _motor2Running = false;
    _conveyorRunning = false;

    _systemRunning = false;
    setSystemStatus(FeederStatus.stop);
    notifyListeners();
  }

  /// Returns false if the system was already running.
  bool startSystem() {
    if (_systemRunning) return false;

    _systemRunning = true;
    setSystemStatus(FeederStatus.run);

    final now = hardware.millis();

    // Motor 1 always runs, alternating direction each start.
    _motor1Dir = !_motor1Dir;
    _motor1Running = true;
    _motor1StartTime = now;
    _motor1StopTime = now;
    _motor1DirActive = true;

    if (_runMode == 2) {
      _motor2Dir = !_motor2Dir;
      _motor2Running = true;
      _motor2StartTime = now;
      _motor2StopTime = now;
      _motor2DirActive = true;
    }

    _conveyor(true);
    _conveyorRunning = true;
    _conveyorStartTime = now;

    _ensureTicker();
    notifyListeners();
    return true;
  }

  void _finishIfIdle() {
    if (!_motor1Running && !_motor2Running && _systemRunning) {
      _systemRunning = false;
      setSystemStatus(FeederStatus.ready);
    }
  }

  /// Physical START/STOP buttons, falling edge; STOP has priority.
  void handleButtons() {
    final btnStart = hardware.digitalRead(FeederPins.buttonStart);
    final btnStop = hardware.digitalRead(FeederPins.buttonStop);

    if (_lastButtonStop && !btnStop) stopAllMotor();
    if (_lastButtonStart && !btnStart) startSystem();

    _lastButtonStart = btnStart;
    _lastButtonStop = btnStop;
  }

  /// Active LOW, 5 samples, pressed when at least 3 read LOW.
  bool readLimit(int pin) {
    var count = 0;
    for (var i = 0; i < 5; i++) {
      if (!hardware.digitalRead(pin)) count++;
    }
    return count >= 3;
  }

  void handleMotor1() {
    if (!_systemRunning || !_motor1Running) return;

    if (hardware.millis() - _motor1StartTime < limitIgnoreTimeMs) {
      _motor1(true, _motor1Dir);
      return;
    }

    if (readLimit(FeederPins.limit1) || readLimit(FeederPins.limit2)) {
      _motor1(false, _motor1Dir);
      _motor1Running = false;
      _finishIfIdle();
      return;
    }

    _motor1(true, _motor1Dir);
  }

  void handleMotor2() {
    if (_runMode == 1) {
      if (_motor2Running) {
        _motor2(false, _motor2Dir);
        _motor2Running = false;
        _finishIfIdle();
      }
      return;
    }
    if (!_systemRunning || !_motor2Running) return;

    if (hardware.millis() - _motor2StartTime < limitIgnoreTimeMs) {
      _motor2(true, _motor2Dir);
      return;
    }

    if (readLimit(FeederPins.limit3) || readLimit(FeederPins.limit4)) {
      _motor2(false, _motor2Dir);
      _motor2Running = false;
      _finishIfIdle();
      return;
    }

    _motor2(true, _motor2Dir);
  }

  void handleConveyor() {
    if (!_conveyorRunning) return;
    if (hardware.millis() - _conveyorStartTime >= _conveyorTime * 1000) {
      _conveyor(false);
      _conveyorRunning = false;
    }
  }

  void handleMotor1DirTimeout() {
    if (!_motor1Running &&
        _motor1DirActive &&
        hardware.millis() - _motor1StopTime > dirTimeoutMs) {
      hardware.digitalWrite(FeederPins.relay3, false);
      _motor1DirActive = false;
    }
  }

  void handleMotor2DirTimeout() {
    if (!_motor2Running &&
        _motor2DirActive &&
        hardware.millis() - _motor2StopTime > dirTimeoutMs) {
      hardware.digitalWrite(FeederPins.relay5, false);
      _motor2DirActive = false;
    }
  }

  /// One pass of the firmware `loop()` core.
  void tick() {
    handleButtons();
    handleMotor1();
    handleMotor2();
    handleConveyor();
    handleMotor1DirTimeout();
    handleMotor2DirTimeout();
    checkSchedule();
    notifyListeners();
    if (!isActive) _stopTicker();
  }

  void _ensureTicker() {
    if (!autoTick || _ticker != null) return;
    _ticker = Timer.periodic(tickInterval, (_) => tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ================= MQTT CALLBACK =================

  void handleMqttMessage(String topic, String payload) {
    if (topic == FeederTopics.setPakan) {
      final doc = _tryDecode(payload);
      if (doc == null) return;
      if (doc is Map && doc['run'] == 1) {
        unawaited(feedNow());
      }
    }

    if (topic == FeederTopics.status) {
      final doc = _tryDecode(payload);
      if (doc != null) {
        final value = doc is Map ? doc['pakan'] : null;
        _client2Status = value is String ? value : '-';
        notifyListeners();
      }
    }

    if (topic == FeederTopics.setJadwal) {
      final doc = _tryDecode(payload);
      if (doc == null || doc is! List) return;
      _schedules = parseScheduleArray(doc);
      _scheduleChanged = true;
      notifyListeners();
    }
  }

  static Object? _tryDecode(String payload) {
    try {
      return jsonDecode(payload);
    } on FormatException {
      return null;
    }
  }

  // ================= JADWAL =================

  /// EEPROM save format.
  String schedulesToJson() =>
      jsonEncode([for (final s in _schedules) s.toJson()]);

  /// EEPROM load: empty or invalid JSON keeps the current schedules; a
  /// non-array root clears them.
  void restoreSchedules(String? json) {
    if (json == null || json.isEmpty) return;
    final doc = _tryDecode(json);
    if (doc == null) return;
    _schedules = doc is List ? parseScheduleArray(doc) : [];
    notifyListeners();
  }

  /// Keypad save: `inputTime` "HHMM" plus checked days (index 0 = Minggu).
  /// Needs at least one day and a free slot.
  bool addSchedule(String inputTime, List<bool> daySelected) {
    if (_schedules.length >= maxSchedule) return false;
    if (!isValidTime(inputTime)) return false;

    final days = <String>[
      for (var i = 0; i < daysOfTheWeek.length; i++)
        if (i < daySelected.length && daySelected[i]) daysOfTheWeek[i],
    ];
    if (days.isEmpty) return false;

    _schedules = [
      ..._schedules,
      FeederSchedule(
        time: '${inputTime.substring(0, 2)}:${inputTime.substring(2, 4)}',
        days: days,
      ),
    ];
    notifyListeners();
    return true;
  }

  bool deleteSchedule(int index) {
    if (index < 0 || index >= _schedules.length) return false;
    _schedules = [..._schedules]..removeAt(index);
    notifyListeners();
    return true;
  }

  String scheduleSignature() {
    final s = StringBuffer();
    for (final schedule in _schedules) {
      s.write(schedule.time);
      schedule.days.forEach(s.write);
    }
    return s.toString();
  }

  NextSchedule getNextSchedule() {
    final now = _clock();
    final nowMinutes = now.hour * 60 + now.minute;
    final today = dayOfTheWeek(now);

    var result = NextSchedule.none;
    var bestDiff = 999999;

    for (final schedule in _schedules) {
      if (schedule.time.length < 5) continue;

      final hour = arduinoToInt(schedule.time.substring(0, 2));
      final minute = arduinoToInt(schedule.time.substring(3, 5));
      final schedMinutes = hour * 60 + minute;

      for (final dayStr in schedule.days) {
        final schedDay = daysOfTheWeek.indexOf(dayStr);
        if (schedDay == -1) continue;

        int totalDiff;
        if (schedDay == today) {
          totalDiff = schedMinutes > nowMinutes
              ? schedMinutes - nowMinutes
              : 7 * 1440 - (nowMinutes - schedMinutes);
        } else {
          var dayDiff = schedDay - today;
          if (dayDiff < 0) dayDiff += 7;
          totalDiff = dayDiff * 1440 + (schedMinutes - nowMinutes);
        }

        if (totalDiff < bestDiff) {
          bestDiff = totalDiff;
          result = NextSchedule(
            day: daysOfTheWeek[schedDay],
            time: schedule.time,
            diff: totalDiff,
          );
        }
      }
    }
    return result;
  }

  List<String> getTodaySchedules([int maxResult = maxSchedule]) {
    final today = daysOfTheWeek[dayOfTheWeek(_clock())];
    final result = <String>[];
    for (final schedule in _schedules) {
      if (schedule.days.contains(today) && result.length < maxResult) {
        result.add(schedule.time);
      }
    }
    return result;
  }

  /// Starts the system once per matching day + minute.
  void checkSchedule() {
    final now = _clock();
    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dayName = daysOfTheWeek[dayOfTheWeek(now)];

    for (final schedule in _schedules) {
      if (schedule.time != nowTime) continue;
      if (!schedule.days.contains(dayName)) continue;
      final key = dayName + nowTime;
      if (key != _lastTrigger) {
        _lastTrigger = key;
        startSystem();
      }
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

/// Simulated relays, limit switches and buttons for running the logic
/// without the ESP32. Each motor travels between two limit switches;
/// DIR HIGH moves toward the second switch. Motors start at the second
/// switch because the first start flips DIR to LOW.
class SimulatedFeederHardware implements FeederHardware {
  SimulatedFeederHardware({
    this.motor1TravelMs = 4000,
    this.motor2TravelMs = 5000,
    int Function()? millisClock,
    Future<void> Function(int ms)? delayFn,
  })  : _millisClock = millisClock,
        _delayFn = delayFn,
        _motor1Pos = motor1TravelMs,
        _motor2Pos = motor2TravelMs {
    _lastUpdate = millis();
  }

  final int motor1TravelMs;
  final int motor2TravelMs;
  final int Function()? _millisClock;
  final Future<void> Function(int ms)? _delayFn;
  final Stopwatch _stopwatch = Stopwatch()..start();
  final Map<int, bool> _pins = {};

  int _motor1Pos;
  int _motor2Pos;
  int _lastUpdate = 0;

  bool pin(int pin) => _pins[pin] ?? false;
  int get motor1Position => _motor1Pos;
  int get motor2Position => _motor2Pos;

  @override
  int millis() => _millisClock?.call() ?? _stopwatch.elapsedMilliseconds;

  @override
  Future<void> delay(int ms) =>
      _delayFn?.call(ms) ?? Future<void>.delayed(Duration(milliseconds: ms));

  @override
  void digitalWrite(int pin, bool high) {
    _advance();
    _pins[pin] = high;
  }

  @override
  bool digitalRead(int pin) {
    _advance();
    switch (pin) {
      case FeederPins.buttonStart:
      case FeederPins.buttonStop:
        return true;
      case FeederPins.limit1:
        return _motor1Pos > 0;
      case FeederPins.limit2:
        return _motor1Pos < motor1TravelMs;
      case FeederPins.limit3:
        return _motor2Pos > 0;
      case FeederPins.limit4:
        return _motor2Pos < motor2TravelMs;
      default:
        return _pins[pin] ?? false;
    }
  }

  void _advance() {
    final now = millis();
    final dt = now - _lastUpdate;
    _lastUpdate = now;
    if (dt <= 0) return;
    if (pin(FeederPins.relay2)) {
      _motor1Pos = (_motor1Pos + (pin(FeederPins.relay3) ? dt : -dt))
          .clamp(0, motor1TravelMs);
    }
    if (pin(FeederPins.relay4)) {
      _motor2Pos = (_motor2Pos + (pin(FeederPins.relay5) ? dt : -dt))
          .clamp(0, motor2TravelMs);
    }
  }
}
