import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/futechi_app.dart';
import 'config/env.dart';
import 'data/feeder_link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi media_kit — wajib dipanggil sebelum Player pertama dibuat.
  // Lihat: https://github.com/alexmercerind/media_kit#readme
  MediaKit.ensureInitialized();

  // Konfigurasi runtime dari asset `.env` (kredensial broker MQTT, topik,
  // URL backend AI). Lihat `.env.example` untuk daftar variabelnya.
  await Env.load();

  // Auto-connect MQTT saat aplikasi start (bootstrap di background + retry)
  unawaited(sharedFeederLink.autoConnect());

  runApp(const FutechiApp());
}
