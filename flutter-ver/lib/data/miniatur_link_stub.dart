import 'miniatur_link.dart';

MiniaturLink createMiniaturLink(MiniaturLinkConfig config) =>
    _UnsupportedMiniaturLink();

/// Platform tanpa socket TCP (web). Browser hanya bisa MQTT lewat
/// WebSocket (`MqttBrowserClient`), jadi implementasi TCP di
/// `MqttMiniaturLink` tidak tersedia di sini — sama seperti feeder.
class _UnsupportedMiniaturLink extends MiniaturLink {
  @override
  MiniaturLinkState get state => MiniaturLinkState.unsupported;

  @override
  String? get lastError => 'MQTT tidak didukung di platform ini';

  @override
  Future<bool> connect() async => false;

  @override
  Future<bool> publishCommand(Map<String, Object?> command) async => false;

  @override
  Future<void> disconnect() async {}
}
