/// Koneksi ke perangkat feeder ESP32 melalui MQTT.
///
/// Aplikasi bersifat **master**: ia mengirim perintah ke topik `set/pakan`
/// (dan nanti `set/jadwal`), lalu menampilkan status yang dilaporkan
/// perangkat pada topik `status`. Perangkat bersifat **slave**.
///
/// Konfigurasi dibaca dari asset `.env` lewat [Env] (lihat `.env.example`),
/// dengan urutan prioritas:
///
/// 1. nilai eksplisit yang diberikan ke [FeederLinkConfig];
/// 2. `--dart-define` (MQTT_HOST, MQTT_PORT, MQTT_USER, MQTT_PASS, MQTT_CLIENT_ID);
/// 3. isi `.env`;
/// 4. nilai default di [Env].
library;

import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'feeder.dart';
import 'feeder_link_stub.dart'
    if (dart.library.io) 'feeder_link_mqtt.dart' as impl;

enum FeederLinkState { disconnected, connecting, connected, unsupported, error }

class FeederLinkConfig {
  const FeederLinkConfig({
    required this.host,
    this.port = 1883,
    this.username = '',
    this.password = '',
    this.clientId,
  });

  /// Membaca konfigurasi dari `--dart-define`, lalu jatuh ke `.env`.
  ///
  /// `String.fromEnvironment` harus dipanggil dengan nilai default literal,
  /// jadi polanya `_override(...) ?? Env.xxx`.
  factory FeederLinkConfig.fromEnvironment() {
    final host = _override(const String.fromEnvironment('MQTT_HOST'));
    final port =
        int.tryParse(_override(const String.fromEnvironment('MQTT_PORT')) ?? '');
    final user = _override(const String.fromEnvironment('MQTT_USER'));
    final pass = _override(const String.fromEnvironment('MQTT_PASS'));
    final clientId = _override(const String.fromEnvironment('MQTT_CLIENT_ID'));

    return FeederLinkConfig(
      host: host ?? Env.mqttHost,
      port: port ?? Env.mqttPort,
      username: user ?? Env.mqttUser,
      password: pass ?? Env.mqttPass,
      clientId: clientId ?? Env.mqttClientId,
    );
  }

  static String? _override(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  final String host;
  final int port;
  final String username;
  final String password;

  /// Client ID tetap. Null → implementasi memakai ID acak
  /// `futechi-app-<8 hex>` agar tidak bentrok dengan `ESP32_FEEDER`.
  final String? clientId;

  bool get hasCredentials => username.isNotEmpty || password.isNotEmpty;

  /// Ringkasan aman untuk log/diagnostik — tidak pernah memuat password.
  String get description =>
      '$host:$port user=${username.isEmpty ? '-' : username} '
      'clientId=${clientId ?? "<acak>"}';

  @override
  String toString() => 'FeederLinkConfig($description)';
}

abstract class FeederLink extends ChangeNotifier {
  FeederLinkState get state;
  String? get lastError;

  /// Called for every message on subscribed topics.
  void Function(String topic, String payload)? onMessage;

  /// Koneksi + subscribe topik. Aman dipanggil berkali-kali.
  Future<bool> connect();

  /// Memutus koneksi lama lalu menyambung kembali.
  Future<bool> reconnect() async {
    debugPrint('[FeederLink] reconnect() dipanggil');
    await disconnect();
    return connect();
  }

  /// Sends `{"run":1}` to the feed topic, connecting first if needed.
  Future<bool> publishFeedNow();

  /// Mengirim seluruh daftar jadwal ke perangkat (`[{"on":..,"days":[..]}]`).
  Future<bool> publishSchedule(List<FeederSchedule> schedules);

  Future<void> disconnect();

  /// True saat koneksi sedang dibuka.
  bool get isBusy => state == FeederLinkState.connecting;

  /// True bila MQTT TCP tidak tersedia di platform ini (web).
  bool get isUnsupported => state == FeederLinkState.unsupported;

  /// Dipanggil saat aplikasi start (dari `main.dart`) atau saat butuh auto-connect dengan retry.
  Future<bool> autoConnect({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    debugPrint('[FeederLink] autoConnect() dipanggil (maxRetries=$maxRetries)');
    if (isUnsupported) {
      debugPrint('[FeederLink] dilewati: MQTT tidak didukung di platform ini');
      return false;
    }
    if (state == FeederLinkState.connected) {
      debugPrint('[FeederLink] sudah terhubung, tidak perlu menyambung ulang');
      return true;
    }
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      debugPrint('[FeederLink] autoConnect mencoba koneksi (percobaan $attempt/$maxRetries)...');
      final ok = await connect();
      if (ok) {
        debugPrint('[FeederLink] autoConnect berhasil pada percobaan $attempt');
        return true;
      }
      if (attempt < maxRetries) {
        debugPrint('[FeederLink] autoConnect gagal, menunggu jeda sebelum percobaan berikutnya...');
        await Future<void>.delayed(retryDelay);
      }
    }
    debugPrint('[FeederLink] autoConnect gagal setelah $maxRetries percobaan → state=$state');
    return false;
  }
}

FeederLink createFeederLink(FeederLinkConfig config) =>
    impl.createFeederLink(config);

final FeederLink sharedFeederLink =
    createFeederLink(FeederLinkConfig.fromEnvironment());
