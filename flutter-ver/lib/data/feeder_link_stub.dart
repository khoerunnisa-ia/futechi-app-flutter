import 'feeder.dart';
import 'feeder_link.dart';

FeederLink createFeederLink(FeederLinkConfig config) => _UnsupportedFeederLink();

/// Platform tanpa socket TCP (web). Browser hanya bisa MQTT lewat WebSocket
/// (`MqttBrowserClient`), jadi implementasi TCP di `MqttFeederLink` tidak
/// tersedia di sini.
class _UnsupportedFeederLink extends FeederLink {
  @override
  FeederLinkState get state => FeederLinkState.unsupported;

  @override
  String? get lastError => 'MQTT tidak didukung di platform ini';

  @override
  Future<bool> connect() async => false;

  @override
  Future<bool> reconnect() async => false;

  @override
  Future<bool> publishFeedNow() async => false;

  @override
  Future<bool> publishSchedule(List<FeederSchedule> schedules) async => false;

  @override
  Future<void> disconnect() async {}
}
