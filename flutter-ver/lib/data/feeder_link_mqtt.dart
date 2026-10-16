import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';

import 'feeder.dart';
import 'feeder_link.dart';

FeederLink createFeederLink(FeederLinkConfig config) => MqttFeederLink(config);

class MqttFeederLink extends FeederLink {
  MqttFeederLink(this.config);

  final FeederLinkConfig config;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  FeederLinkState _state = FeederLinkState.disconnected;
  String? _lastError;
  Future<bool>? _connecting;

  @override
  FeederLinkState get state => _state;

  @override
  String? get lastError => _lastError;

  void _setState(FeederLinkState state, [String? error]) {
    _state = state;
    _lastError = error;
    notifyListeners();
  }

  @override
  Future<bool> connect() {
    if (_state == FeederLinkState.connected) return Future.value(true);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<bool> _connect() async {
    _setState(FeederLinkState.connecting);

    // Must differ from the firmware id "ESP32_FEEDER" or the broker drops it.
    final clientId = 'futechi-app-${const Uuid().v4().substring(0, 8)}';
    final client = MqttServerClient.withPort(config.host, clientId, config.port)
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 5000
      ..logging(on: false)
      ..connectionMessage =
          MqttConnectMessage().withClientIdentifier(clientId).startClean();
    client.onDisconnected = () {
      if (_client == client) _setState(FeederLinkState.disconnected);
    };

    try {
      await client.connect(
        config.username.isEmpty ? null : config.username,
        config.password.isEmpty ? null : config.password,
      );
    } catch (_) {
      client.disconnect();
      _setState(FeederLinkState.error, 'Gagal terhubung ke broker MQTT');
      return false;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      client.disconnect();
      _setState(FeederLinkState.error, 'Broker MQTT menolak koneksi');
      return false;
    }

    _client = client;
    client.subscribe(FeederTopics.status, MqttQos.atMostOnce);
    await _updates?.cancel();
    _updates = client.updates?.listen((messages) {
      for (final message in messages) {
        final publish = message.payload;
        if (publish is! MqttPublishMessage) continue;
        final payload =
            MqttPublishPayload.bytesToStringAsString(publish.payload.message);
        onMessage?.call(message.topic, payload);
      }
    });
    _setState(FeederLinkState.connected);
    return true;
  }

  @override
  Future<bool> publishFeedNow() async {
    if (!await connect()) return false;
    final client = _client;
    if (client == null) return false;
    final builder = MqttClientPayloadBuilder()..addString('{"run":1}');
    client.publishMessage(
        FeederTopics.setPakan, MqttQos.atMostOnce, builder.payload!);
    return true;
  }

  @override
  Future<void> disconnect() async {
    await _updates?.cancel();
    _updates = null;
    final client = _client;
    _client = null;
    client?.disconnect();
    _setState(FeederLinkState.disconnected);
  }

  @override
  void dispose() {
    _updates?.cancel();
    _client?.disconnect();
    super.dispose();
  }
}
