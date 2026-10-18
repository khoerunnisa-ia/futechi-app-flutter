import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final int humidity;
  final String locationSource;

  const WeatherData({
    required this.temperature,
    required this.humidity,
    required this.locationSource,
  });
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  // Fallback koordinat kandang (Surabaya, Jawa Timur) bila GPS tidak aktif/ditolak
  static const double defaultLat = -7.3150;
  static const double defaultLon = 112.7480;

  Future<WeatherData> fetchCurrentWeather() async {
    double lat = defaultLat;
    double lon = defaultLon;
    String source = 'Kandang (Default)';

    try {
      final hasPermission = await _checkAndRequestPermission();
      if (hasPermission) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = position.latitude;
        lon = position.longitude;
        source = 'GPS Terdeteksi';
      }
    } catch (e) {
      debugPrint('[WeatherService] Gagal membaca lokasi GPS, menggunakan fallback: $e');
    }

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 30.5;
          final hum = (current['relative_humidity_2m'] as num?)?.round() ?? 70;
          return WeatherData(
            temperature: temp,
            humidity: hum,
            locationSource: source,
          );
        }
      }
    } catch (e) {
      debugPrint('[WeatherService] Gagal fetch data Open-Meteo: $e');
    }

    // Default fallback bila jaringan offline
    return const WeatherData(
      temperature: 30.8,
      humidity: 72,
      locationSource: 'Offline Fallback',
    );
  }

  Future<bool> _checkAndRequestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[WeatherService] Error izin lokasi: $e');
      return false;
    }
  }
}
