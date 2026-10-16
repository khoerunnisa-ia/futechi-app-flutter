import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';

import 'feeder.dart';
import 'feeder_link.dart';

FeederLink createFeederLink(FeederLinkConfig config) => MqttFeederLink(config);

/// Implementasi [FeederLink] di atas `mqtt_client` (Android/iOS/desktop).
///
/// Aplikasi = **master**, perangkat = **slave**:
/// - publish perintah ke `set/pakan` / `set/jadwal`;
/// - subscribe `status` untuk status yang dilaporkan perangkat.
///
/// Implementasi [FeederLink] di atas `mqtt_client` (Android/iOS/desktop).
///
/// Aplikasi = **master**, perangkat = **slave**:
/// - publish perintah ke `set/pakan` / `set/jadwal`;
/// - subscribe `status` untuk status yang dilaporkan perangkat.
///
/// Semua langkah penting dicatat lewat `debugPrint` dengan awalan `[MQTT]`
/// supaya bisa dipantau di konsol `flutter run --verbose`.
class MqttFeederLink extends FeederLink {
  MqttFeederLink(this.config);

  final FeederLinkConfig config;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  FeederLinkState _state = FeederLinkState.disconnected;
  String? _lastError;
  Future<bool>? _connecting;
  bool _disposed = false;

  @override
  FeederLinkState get state => _state;

  @override
  String? get lastError => _lastError;

  void _setState(FeederLinkState state, [String? error]) {
    _state = state;
    _lastError = error;
    debugPrint('[MQTT] State changed: ${state.name}${error != null ? " (error: $error)" : ""}');
    if (_disposed) return;
    notifyListeners();
  }

  @override
  Future<bool> connect() {
    if (_state == FeederLinkState.connected) {
      debugPrint('[MQTT] connect() dilewati: sudah terhubung ke broker');
      return Future.value(true);
    }
    if (_state == FeederLinkState.unsupported) {
      debugPrint('[MQTT] connect() dibatalkan: platform tidak didukung');
      return Future.value(false);
    }
    if (_connecting != null) {
      debugPrint('[MQTT] connect() sedang berjalan, menunggu hasil...');
      return _connecting!;
    }
    return _connecting = _connect().whenComplete(() => _connecting = null);
  }

  @override
  Future<bool> reconnect() async {
    debugPrint('[MQTT] reconnect() dipanggil: memutus koneksi lama...');
    await disconnect();
    debugPrint('[MQTT] reconnect(): menyambung ulang ke broker...');
    return connect();
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
        return 'Broker MQTT menolak koneksi (alasan tidak dispesifikasikan)';
    }
  }

  Future<bool> _connect() async {
    _setState(FeederLinkState.connecting);

    // Client ID dari `.env` (MQTT_CLIENT_ID), atau ID acak bila kosong.
    // Harus selalu berbeda dari "ESP32_FEEDER" milik firmware, jika tidak
    // broker akan memutus salah satu koneksi.
    final clientId = config.clientId ??
        'futechi-app-${const Uuid().v4().substring(0, 8)}';
    final client = MqttServerClient.withPort(config.host, clientId, config.port)
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 5000
      ..logging(on: false)
      ..connectionMessage =
          MqttConnectMessage().withClientIdentifier(clientId).startClean();

    client.onConnected = () {
      debugPrint('[MQTT] Callback onConnected: terhubung ke broker ${config.host}:${config.port}');
    };

    client.onDisconnected = () {
      debugPrint('[MQTT] Callback onDisconnected: koneksi terputus dari broker');
      if (_client == client) {
        _setState(FeederLinkState.disconnected);
      }
    };

    client.onSubscribed = (String topic) {
      debugPrint('[MQTT] Callback onSubscribed: berhasil subscribe topik "$topic"');
    };

    client.onSubscribeFail = (String topic) {
      debugPrint('[MQTT] Callback onSubscribeFail: GAGAL subscribe topik "$topic"');
    };

    client.pongCallback = () {
      debugPrint('[MQTT] Ping response (pong) diterima dari broker');
    };

    debugPrint('[MQTT] Menghubungkan ke broker: ${config.description}');
    try {
      await client.connect(
        config.username.isEmpty ? null : config.username,
        config.password.isEmpty ? null : config.password,
      );
    } catch (error) {
      client.disconnect();
      final message = 'Gagal terhubung ke broker MQTT: $error';
      _setState(FeederLinkState.error, message);
      debugPrint('[MQTT] Gagal koneksi (exception): $error');
      return false;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      final code = client.connectionStatus?.returnCode;
      client.disconnect();
      final reason = _errorMessageForReturnCode(code);
      _setState(FeederLinkState.error, reason);
      debugPrint('[MQTT] Koneksi ditolak oleh broker: returnCode=$code ($reason)');
      return false;
    }

    _client = client;
    debugPrint('[MQTT] Berhasil terhubung! Mendaftarkan subscription ke: ${FeederTopics.status}');
    final subscription = client.subscribe(FeederTopics.status, MqttQos.atMostOnce);
    if (subscription == null) {
      debugPrint('[MQTT] Peringatan: Subscription ke ${FeederTopics.status} mengembalikan null');
    }

    await _updates?.cancel();
    _updates = client.updates?.listen(
      (messages) {
        for (final message in messages) {
          final publish = message.payload;
          if (publish is! MqttPublishMessage) continue;
          final payload =
              MqttPublishPayload.bytesToStringAsString(publish.payload.message);
          debugPrint('[MQTT] Pesan diterima [${message.topic}]: $payload');
          onMessage?.call(message.topic, payload);
        }
      },
      onError: (Object error) {
        debugPrint('[MQTT] Stream updates error: $error');
      },
      onDone: () {
        debugPrint('[MQTT] Stream updates ditutup');
      },
    );

    _setState(FeederLinkState.connected);
    return true;
  }

  @override
  Future<bool> publishFeedNow() async {
    debugPrint('[MQTT] publishFeedNow() dipanggil');
    if (!await connect()) {
      debugPrint('[MQTT] publishFeedNow() gagal: tidak dapat menyambung ke broker');
      return false;
    }
    final client = _client;
    if (client == null || client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] publishFeedNow() gagal: client tidak terkoneksi');
      return false;
    }
    try {
      final builder = MqttClientPayloadBuilder()..addString('{"run":1}');
      final msgId = client.publishMessage(
        FeederTopics.setPakan,
        MqttQos.atMostOnce,
        builder.payload!,
      );
      debugPrint('[MQTT] publish ${FeederTopics.setPakan} {"run":1} berhasil dikirim (msgId=$msgId)');
      return true;
    } catch (e) {
      debugPrint('[MQTT] Error saat publishFeedNow: $e');
      return false;
    }
  }

  @override
  Future<bool> publishSchedule(List<FeederSchedule> schedules) async {
    debugPrint('[MQTT] publishSchedule() dipanggil dengan ${schedules.length} jadwal');
    if (!await connect()) {
      debugPrint('[MQTT] publishSchedule() gagal: tidak dapat menyambung ke broker');
      return false;
    }
    final client = _client;
    if (client == null || client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] publishSchedule() gagal: client tidak terkoneksi');
      return false;
    }
    try {
      final jsonList = schedules.map((s) => s.toJson()).toList();
      final payload = jsonEncode(jsonList);
      final builder = MqttClientPayloadBuilder()..addString(payload);
      final msgId = client.publishMessage(
        FeederTopics.setJadwal,
        MqttQos.atMostOnce,
        builder.payload!,
      );
      debugPrint('[MQTT] publish ${FeederTopics.setJadwal} $payload berhasil dikirim (msgId=$msgId)');
      return true;
    } catch (e) {
      debugPrint('[MQTT] Error saat publishSchedule: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    debugPrint('[MQTT] disconnect() dipanggil');
    await _updates?.cancel();
    _updates = null;
    final client = _client;
    _client = null;
    client?.disconnect();
    _setState(FeederLinkState.disconnected);
  }

  @override
  void dispose() {
    debugPrint('[MQTT] dispose() dipanggil');
    _disposed = true;
    _updates?.cancel();
    _client?.disconnect();
    super.dispose();
  }
}
