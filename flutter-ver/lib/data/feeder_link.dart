/// Connection to the ESP32 feeder over MQTT.
///
/// Publishes the same `client2/set/pakan {"run":1}` command the firmware
/// listens to and forwards `client2/status` messages. Broker settings come
/// from `--dart-define` (MQTT_HOST, MQTT_PORT, MQTT_USER, MQTT_PASS).
library;

import 'package:flutter/foundation.dart';

import 'feeder_link_stub.dart'
    if (dart.library.io) 'feeder_link_mqtt.dart' as impl;

enum FeederLinkState { disconnected, connecting, connected, unsupported, error }

class FeederLinkConfig {
  const FeederLinkConfig({
    required this.host,
    this.port = 1883,
    this.username = '',
    this.password = '',
  });

  factory FeederLinkConfig.fromEnvironment() => const FeederLinkConfig(
        host: String.fromEnvironment('MQTT_HOST',
            defaultValue: 'mqtt.stiatech.my.id'),
        port: int.fromEnvironment('MQTT_PORT', defaultValue: 1883),
        username: String.fromEnvironment('MQTT_USER'),
        password: String.fromEnvironment('MQTT_PASS'),
      );

  final String host;
  final int port;
  final String username;
  final String password;
}

abstract class FeederLink extends ChangeNotifier {
  FeederLinkState get state;
  String? get lastError;

  /// Called for every message on subscribed topics.
  void Function(String topic, String payload)? onMessage;

  Future<bool> connect();

  /// Sends `{"run":1}` to `client2/set/pakan`, connecting first if needed.
  Future<bool> publishFeedNow();

  Future<void> disconnect();
}

FeederLink createFeederLink(FeederLinkConfig config) =>
    impl.createFeederLink(config);

final FeederLink sharedFeederLink =
    createFeederLink(FeederLinkConfig.fromEnvironment());
