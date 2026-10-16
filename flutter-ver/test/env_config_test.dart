import 'package:flutter_test/flutter_test.dart';
import 'package:futechi/config/env.dart';
import 'package:futechi/data/feeder.dart';
import 'package:futechi/data/feeder_link.dart';

/// Memastikan asset `.env` benar-benar terbaca dan nilai di dalamnya
/// mengalir ke `FeederLinkConfig` serta `FeederTopics`.

/// Test ini memuat `.env` asli dari `pubspec.yaml`. Bila `.env` belum dibuat,
/// ia dilewati dengan pesan yang jelas (jalankan `Copy-Item .env.example .env`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asset .env dimuat dan mengisi konfigurasi MQTT', () async {
    await Env.load();

    if (!Env.loaded) {
      markTestSkipped(
        'asset .env tidak ditemukan — salin dari .env.example lalu jalankan ulang.',
      );
      return;
    }

    // Nilai dari .env (bukan default hardcoded).
    expect(Env.mqttHost, isNotEmpty);
    expect(Env.mqttPort, greaterThan(0));
    expect(Env.topicFeed, isNotEmpty);
    expect(Env.topicSchedule, isNotEmpty);
    expect(Env.topicStatus, isNotEmpty);

    // Aliran .env → FeederLinkConfig.
    final config = FeederLinkConfig.fromEnvironment();
    expect(config.host, Env.mqttHost);
    expect(config.port, Env.mqttPort);
    expect(config.username, Env.mqttUser);
    expect(config.password, Env.mqttPass);
    expect(config.clientId, Env.mqttClientId);

    // Aliran .env → FeederTopics.
    expect(FeederTopics.setPakan, Env.topicFeed);
    expect(FeederTopics.setJadwal, Env.topicSchedule);
    expect(FeederTopics.status, Env.topicStatus);

    // Diagnostik tidak boleh membocorkan password.
    if (config.password.isNotEmpty) {
      expect(config.description, isNot(contains(config.password)));
    }
  });

  test('MQTT_CLIENT_ID dari .env tidak bentrok dengan firmware', () async {
    await Env.load();
    if (!Env.loaded) {
      markTestSkipped('asset .env tidak tersedia.');
      return;
    }

    final clientId = FeederLinkConfig.fromEnvironment().clientId;
    // Null berarti aplikasi memakai ID acak `futechi-app-<8 hex>`.
    expect(clientId, isNot('ESP32_FEEDER'));
    expect(clientId ?? 'futechi-app-xxxxxxxx', isNot('ESP32_FEEDER'));
  });

  test('konfigurasi CCTV dan Direct Cloud LLM tersedia', () async {
    await Env.load();

    // Default fallbacks untuk LLM
    expect(Env.llmBaseUrl, isNotEmpty);
    expect(Env.llmModel, isNotEmpty);

    // CCTV fallback values
    expect(Env.cctvAutoPlay, isA<bool>());
  });
}
