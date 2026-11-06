import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';

import 'miniatur.dart';
import 'miniatur_link.dart';

MiniaturLink createMiniaturLink(MiniaturLinkConfig config) =>
    MqttMiniaturLink(config);

/// Implementasi [MiniaturLink] di atas `mqtt_client` (Android/iOS/desktop).
///
/// App = **master**, perangkat miniatur = **slave**:
/// - publish perintah JSON ke [MiniaturTopics.set];
/// - subscribe [MiniaturTopics.status] untuk status firmware mendatang.
///
/// Perangkat miniatur saat ini belum memiliki klien MQTT, sehingga
/// pesan perintah tetap sampai ke broker tapi belum dibaca siapa pun —
/// begitu firmware menambah subscriber, kontrol live langsung berfungsi.
/// Semua langkah penting dicatat via `debugPrint` berprefiks `[MiniMQTT]`.
class MqttMiniaturLink extends MiniaturLink {
  MqttMiniaturLink(this.config);

  final MiniaturLinkConfig config;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  MiniaturLinkState _state = MiniaturLinkState.disconnected;
  String? _lastError;
  Future<bool>? _connecting;
  bool _disposed = false;

  @override
  MiniaturLinkState get state => _state;

  @override
  String? get lastError => _lastError;

  void _setState(MiniaturLinkState state, [String? error]) {
    _state = state;
    _lastError = error;
    debugPrint(
        '[MiniMQTT] State changed: ${state.name}${error != null ? " ($error)" : ""}');
    if (_disposed) return;
    notifyListeners();
  }

  @override
  Future<bool> connect() {
    if (_state == MiniaturLinkState.connected) {
      debugPrint('[MiniMQTT] connect() dilewati: sudah terhubung');
      return Future.value(true);
    }
    if (_state == MiniaturLinkState.unsupported) {
      debugPrint('[MiniMQTT] connect() dibatalkan: platform tidak didukung');
      return Future.value(false);
    }
    if (_connecting != null) {
      return _connecting!;
    }
    return _connecting = _connect().whenComplete(() => _connecting = null);
  }

  static String _errorMessageForReturnCode(MqttConnectReturnCode? code) {
    if (code == null) return 'Broker MQTT menolak koneksi (status null)';
    switch (code) {
      case MqttConnectReturnCode.connectionAccepted:
        return 'Koneksi diterima';
      case MqttConnectReturnCode.unacceptedProtocolVersion:
        return 'Versi protokol MQTT tidak didukung oleh broker';
      case MqttConnectReturnCode.identifierRejected:
        return 'Client ID ditolak oleh broker MQTT';
      case MqttConnectReturnCode.brokerUnavailable:
        return 'Server broker MQTT tidak tersedia';
      case MqttConnectReturnCode.badUsernameOrPassword:
        return 'Username atau password broker MQTT salah';
      case MqttConnectReturnCode.notAuthorized:
        return 'Tidak memiliki otorisasi untuk mengakses broker MQTT';
      case MqttConnectReturnCode.noneSpecified:
        return 'Broker MQTT menolak koneksi';
    }
  }

  Future<bool> _connect() async {
    _setState(MiniaturLinkState.connecting);

    // Client ID miniatur HARUS unik terhadap koneksi feeder yang bisa
    // terbuka bersamaan di aplikasi ini.
    final clientId =
        config.clientId ?? 'futechi-miniatur-${const Uuid().v4().substring(0, 8)}';
    final client = MqttServerClient.withPort(config.host, clientId, config.port)
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 5000
      ..logging(on: false)
      ..connectionMessage =
          MqttConnectMessage().withClientIdentifier(clientId).startClean();

    client.onConnected = () {
      debugPrint('[MiniMQTT] Terhubung ke broker ${config.host}:${config.port}');
    };
    client.onDisconnected = () {
      debugPrint('[MiniMQTT] Koneksi terputus dari broker');
      if (_client == client) {
        _setState(MiniaturLinkState.disconnected);
      }
    };
    client.onSubscribed = (String topic) {
      debugPrint('[MiniMQTT] Subscribe berhasil: "$topic"');
    };
    client.onSubscribeFail = (String topic) {
      debugPrint('[MiniMQTT] GAGAL subscribe topik "$topic"');
    };

    debugPrint('[MiniMQTT] Menghubungkan ke broker: ${config.description}');
    try {
      await client.connect(
        config.username.isEmpty ? null : config.username,
        config.password.isEmpty ? null : config.password,
      );
    } catch (error) {
      client.disconnect();
      final message = 'Gagal terhubung ke broker MQTT: $error';
      _setState(MiniaturLinkState.error, message);
      debugPrint('[MiniMQTT] Gagal koneksi (exception): $error');
      return false;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      final code = client.connectionStatus?.returnCode;
      client.disconnect();
      final reason = _errorMessageForReturnCode(code);
      _setState(MiniaturLinkState.error, reason);
      debugPrint('[MiniMQTT] Koneksi ditolak: returnCode=$code');
      return false;
    }

    _client = client;
    // Status miniatur belum dipublish firmware mana pun, tapi tetap
    // disubscribe agar pesan masa depan langsung terekam.
    client.subscribe(MiniaturTopics.status, MqttQos.atMostOnce);

    await _updates?.cancel();
    _updates = client.updates?.listen(
      (messages) {
        for (final message in messages) {
          final publish = message.payload;
          if (publish is! MqttPublishMessage) continue;
          final payload =
              MqttPublishPayload.bytesToStringAsString(publish.payload.message);
          debugPrint('[MiniMQTT] Pesan diterima [${message.topic}]: $payload');
          onMessage?.call(message.topic, payload);
        }
      },
      onError: (Object error) {
        debugPrint('[MiniMQTT] Stream updates error: $error');
      },
    );

    _setState(MiniaturLinkState.connected);
    return true;
  }

  @override
  Future<bool> publishCommand(Map<String, Object?> command) async {
    debugPrint('[MiniMQTT] publishCommand() dipanggil: $command');
    if (!await connect()) {
      debugPrint('[MiniMQTT] publishCommand() gagal: tidak dapat menyambung');
      return false;
    }
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MiniMQTT] publishCommand() gagal: client tidak terkoneksi');
      return false;
    }
    try {
      final payload = jsonEncode(command);
      final builder = MqttClientPayloadBuilder()..addString(payload);
      final msgId = client.publishMessage(
        MiniaturTopics.set,
        MqttQos.atMostOnce,
        builder.payload!,
      );
      debugPrint(
          '[MiniMQTT] publish ${MiniaturTopics.set} $payload (msgId=$msgId)');
      return true;
    } catch (e) {
      debugPrint('[MiniMQTT] Error saat publishCommand: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    debugPrint('[MiniMQTT] disconnect() dipanggil');
    await _updates?.cancel();
    _updates = null;
    final client = _client;
    _client = null;
    client?.disconnect();
    _setState(MiniaturLinkState.disconnected);
  }

  @override
  void dispose() {
    debugPrint('[MiniMQTT] dispose() dipanggil');
    _disposed = true;
    _updates?.cancel();
    _client?.disconnect();
    super.dispose();
  }
}
