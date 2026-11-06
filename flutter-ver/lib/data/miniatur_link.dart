/// Koneksi ke perangkat miniatur ESP32 melalui MQTT.
///
/// Mengikuti pola [FeederLink]: aplikasi bersifat **master** yang
/// mengirim perintah JSON ke `client3/set/miniatur`, lalu menampilkan
/// status yang dilaporkan perangkat pada `client3/status/miniatur`.
/// Perangkat bersifat **slave**.
///
/// PENTING (status implementasi hari ini): firmware `miniaturFutechi`
/// belum memiliki kode MQTT, jadi tidak ada subscriber nyata. Lapisan ini
/// tetap dibangun lengkap supaya forward-compatible — lihat
/// `implementasi_IoT.md`.
///
/// Konfigurasi dibaca dari asset `.env` lewat [Env] dengan urutan
/// prioritas sama seperti feeder:
///
/// 1. nilai eksplisit [MiniaturLinkConfig];
/// 2. `--dart-define` (MQTT_HOST/PORT/USER/PASS, MQTT_MINIATUR_CLIENT_ID);
/// 3. isi `.env`;
/// 4. nilai default [Env].
library;

import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'miniatur.dart';
import 'miniatur_link_stub.dart'
    if (dart.library.io) 'miniatur_link_mqtt.dart' as impl;

enum MiniaturLinkState { disconnected, connecting, connected, unsupported, error }

class MiniaturLinkConfig {
  const MiniaturLinkConfig({
    required this.host,
    this.port = 1883,
    this.username = '',
    this.password = '',
    this.clientId,
  });

  /// Membaca konfigurasi dari `--dart-define`, lalu jatuh ke `.env`.
  factory MiniaturLinkConfig.fromEnvironment() {
    final host = _override(const String.fromEnvironment('MQTT_HOST'));
    final port =
        int.tryParse(_override(const String.fromEnvironment('MQTT_PORT')) ?? '');
    final user = _override(const String.fromEnvironment('MQTT_USER'));
    final pass = _override(const String.fromEnvironment('MQTT_PASS'));
    final clientId =
        _override(const String.fromEnvironment('MQTT_MINIATUR_CLIENT_ID'));

    return MiniaturLinkConfig(
      host: host ?? Env.mqttHost,
      port: port ?? Env.mqttPort,
      username: user ?? Env.mqttUser,
      password: pass ?? Env.mqttPass,
      clientId: clientId ?? Env.mqttMiniaturClientId,
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

  /// Client ID khusus koneksi miniatur. Null → implementasi memakai ID
  /// acak `futechi-miniatur-<8 hex>` supaya TIDAK bertabrakan dengan
  /// koneksi feeder (`MqttFeederLink`) yang bisa terbuka bersamaan di
  /// aplikasi yang sama — client ID ganda membuat broker memutus salah
  /// satu koneksi.
  final String? clientId;

  bool get hasCredentials => username.isNotEmpty || password.isNotEmpty;

  /// Ringkasan aman untuk log/diagnostik — tidak pernah memuat password.
  String get description =>
      '$host:$port user=${username.isEmpty ? '-' : username} '
      'clientId=${clientId ?? "<acak>"}';

  @override
  String toString() => 'MiniaturLinkConfig($description)';
}

abstract class MiniaturLink extends ChangeNotifier {
  MiniaturLinkState get state;
  String? get lastError;

  /// Callback untuk setiap pesan pada topik yang tersubscribe.
  void Function(String topic, String payload)? onMessage;

  /// Koneksi + subscribe topik status. Aman dipanggil berkali-kali.
  Future<bool> connect();

  /// Memutus koneksi lama lalu menyambung kembali.
  Future<bool> reconnect() async {
    debugPrint('[MiniaturLink] reconnect() dipanggil');
    await disconnect();
    return connect();
  }

  /// Mengirim satu perintah JSON ke [MiniaturTopics.set].
  Future<bool> publishCommand(Map<String, Object?> command);

  Future<void> disconnect();

  /// True saat koneksi sedang dibuka.
  bool get isBusy => state == MiniaturLinkState.connecting;

  /// True bila MQTT TCP tidak tersedia di platform ini (web).
  bool get isUnsupported => state == MiniaturLinkState.unsupported;

  /// Auto-connect dengan retry (dipanggil saat halaman dibuka).
  Future<bool> autoConnect({
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    debugPrint('[MiniaturLink] autoConnect() dipanggil (maxRetries=$maxRetries)');
    if (isUnsupported) {
      debugPrint('[MiniaturLink] dilewati: MQTT tidak didukung platform ini');
      return false;
    }
    if (state == MiniaturLinkState.connected) return true;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      debugPrint('[MiniaturLink] percobaan $attempt/$maxRetries...');
      final ok = await connect();
      if (ok) return true;
      if (attempt < maxRetries) {
        await Future<void>.delayed(retryDelay);
      }
    }
    debugPrint('[MiniaturLink] autoConnect gagal setelah $maxRetries percobaan');
    return false;
  }
}

MiniaturLink createMiniaturLink(MiniaturLinkConfig config) =>
    impl.createMiniaturLink(config);

final MiniaturLink sharedMiniaturLink =
    createMiniaturLink(MiniaturLinkConfig.fromEnvironment());
