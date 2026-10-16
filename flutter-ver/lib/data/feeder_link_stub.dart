import 'feeder_link.dart';

FeederLink createFeederLink(FeederLinkConfig config) => _UnsupportedFeederLink();

/// Platforms without TCP sockets (web).
class _UnsupportedFeederLink extends FeederLink {
  @override
  FeederLinkState get state => FeederLinkState.unsupported;

  @override
  String? get lastError => 'MQTT tidak didukung di platform ini';

  @override
  Future<bool> connect() async => false;

  @override
  Future<bool> publishFeedNow() async => false;

  @override
  Future<void> disconnect() async {}
}
