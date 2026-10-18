/// Port of react-js/src/lib/futechi-treatments.ts
///
/// Treatment catalog + reminder/read-notification persistence backed by
/// shared_preferences (replacement for the browser localStorage hooks).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TreatmentStatus { mendesak, terjadwal }

class Treatment {
  const Treatment({
    required this.id,
    required this.name,
    required this.schedule,
    required this.dueLabel,
    required this.dueInDays,
    required this.dueHour,
    required this.dueMinute,
    required this.target,
    required this.status,
    required this.product,
    required this.ingredient,
    required this.form,
    required this.dosage,
    required this.safety,
    required this.steps,
    required this.buyUrl,
    required this.tutorialUrl,
  });

  final String id;
  final String name;
  final String schedule;
  final String dueLabel;

  /// Jadwal relatif terhadap hari ini, dipakai untuk mengurutkan jadwal.
  final int dueInDays;
  final int dueHour;
  final int dueMinute;
  final String target;
  final TreatmentStatus status;
  final String product;
  final String ingredient;
  final String form;
  final String dosage;
  final String safety;
  final List<String> steps;
  final String buyUrl;
  final String tutorialUrl;

  DateTime dueAt(DateTime now) =>
      DateTime(now.year, now.month, now.day + dueInDays, dueHour, dueMinute);
}

const List<Treatment> treatments = [
  Treatment(
    id: 'kalsium-d3',
    name: 'Suplementasi Kalsium & Vitamin D3',
    schedule: 'Hari ini, 08:00 WIB',
    dueLabel: 'Hari ini',
    dueInDays: 0,
    dueHour: 8,
    dueMinute: 0,
    target: 'Batch #24 (Lohmann Brown)',
    status: TreatmentStatus.mendesak,
    product: 'Calci-Layer D3 Liquid ',
    ingredient: 'Kalsium Glukonat, Vitamin D3, dan Fosfor',
    form: 'Cairan larut air minum',
    dosage: '2 ml per liter air minum selama 3 hari berturut-turut.',
    safety:
      'Sangat esensial untuk ayam petelur usia 20 minggu (awal bertelur) demi mencegah kelumpuhan kandang baterai (cage layer fatigue) dan kerabang telur tipis.',
    steps: [
      'Bersihkan nipple drinker atau talang air minum sebelum aplikasi.',
      'Larutkan 2 ml Calci-Layer D3 per 1 liter air minum pagi.',
      'Berikan pada jam 08:00–12:00 saat penyerapan kalsium optimal.',
      'Pantau kualitas ketebalan kerabang telur pertama.',
    ],
    buyUrl: 'https://www.tokopedia.com/search?q=kalsium+vitamin+D3+ayam+petelur',
    tutorialUrl: 'https://www.youtube.com/results?search_query=manajemen+kalsium+ayam+petelur+layer',
  ),
  Treatment(
    id: 'vaksin-eds',
    name: 'Booster ND-IB-EDS (Egg Drop Syndrome)',
    schedule: 'Dalam 3 hari, 07:30 WIB',
    dueLabel: 'Dalam 3 hari',
    dueInDays: 3,
    dueHour: 7,
    dueMinute: 30,
    target: 'Batch #24 (Lohmann Brown)',
    status: TreatmentStatus.terjadwal,
    product: 'Vaksin Inaktif ND-IB-EDS Emulsi Minyak',
    ingredient: 'Virus Newcastle Disease, IB, dan Egg Drop Syndrome 76 inaktif',
    form: 'Emulsi minyak injeksi intramuskular (otot dada)',
    dosage: '0.5 ml per ekor injeksi intramuskular sesuai petunjuk dokter hewan.',
    safety:
      'Wajib dihangatkan ke suhu ruang (25°C) sebelum disuntikkan. Lindungi organ reproduksi layer fase awal produksi telur.',
    steps: [
      'Keluarkan vaksin dari pendingin 2–3 jam sebelum penyuntikan hingga suhu ruang.',
      'Gunakan jarum steril ukuran 18–19G.',
      'Suntikkan secara intramuskular pada otot dada ayam dengan sudut 45 derajat.',
      'Sterilisasi ulang jarum secara berkala setiap 50 ekor.',
    ],
    buyUrl: 'https://www.tokopedia.com/search?q=vaksin+ND+IB+EDS+ayam+petelur',
    tutorialUrl: 'https://www.youtube.com/results?search_query=cara+suntik+vaksin+EDS+ayam+layer',
  ),
  Treatment(
    id: 'anti-stres',
    name: 'Anti-Stres & Elektrolit Transisi Layer',
    schedule: 'Dalam 5 hari, 09:00 WIB',
    dueLabel: 'Dalam 5 hari',
    dueInDays: 5,
    dueHour: 9,
    dueMinute: 0,
    target: 'Batch #24 (Lohmann Brown)',
    status: TreatmentStatus.terjadwal,
    product: 'Stress-Off Layer Soluble',
    ingredient: 'Vitamin C 500mg, Kalium Klorida, Natrium Bikarbonat, Asam Amino Esensial',
    form: 'Serbuk larut air',
    dosage: '1 gram per 2 liter air minum saat cuaca panas atau penyesuaian pakan layer.',
    safety:
      'Membantu adaptasi metabolik Lohmann Brown usia 20 minggu saat hen-day production mulai menanjak.',
    steps: [
      'Larutkan pada air minum di siang hari (10:00–14:00 WIB).',
      'Hindari pencampuran dengan antibiotik atau desinfektan klorin.',
      'Ganti air minum setelah 8 jam.',
    ],
    buyUrl: 'https://www.tokopedia.com/search?q=vitamin+anti+stres+ayam+petelur',
    tutorialUrl: 'https://www.youtube.com/results?search_query=pencegahan+heat+stress+ayam+layer',
  ),
];

Treatment? getTreatment(String id) {
  for (final t in treatments) {
    if (t.id == id) return t;
  }
  return null;
}

class Reminder {
  const Reminder({required this.enabled, this.snoozedUntil});
  final bool enabled;
  final DateTime? snoozedUntil;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (snoozedUntil != null) 'snoozedUntil': snoozedUntil!.toIso8601String(),
      };

  static Reminder fromJson(Map<String, dynamic> json) => Reminder(
        enabled: json['enabled'] as bool? ?? true,
        snoozedUntil: json['snoozedUntil'] != null
            ? DateTime.tryParse(json['snoozedUntil'] as String)
            : null,
      );
}

/// Observable store for reminders + notification read state.
///
/// Replaces the localStorage `useReminders` / `useReadNotifications` hooks.
class TreatmentStore extends ChangeNotifier {
  TreatmentStore._();
  static final TreatmentStore instance = TreatmentStore._();

  static const _reminderKey = 'futechi-reminders-v1';
  static const _readKey = 'futechi-notif-read-v1';
  static const _doneKey = 'futechi-treatment-done-v1';

  Map<String, Reminder> _reminders = {};
  Set<String> _readIds = {};
  Set<String> _doneIds = {};
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _reminders = _decodeReminders(prefs.getString(_reminderKey));
    _readIds = (jsonDecode(prefs.getString(_readKey) ?? '[]') as List<dynamic>? ?? [])
        .whereType<String>()
        .toSet();
    _doneIds = (jsonDecode(prefs.getString(_doneKey) ?? '[]') as List<dynamic>? ?? [])
        .whereType<String>()
        .toSet();
    _loaded = true;
    notifyListeners();
  }

  Map<String, Reminder> get reminders => Map.unmodifiable(_reminders);
  Set<String> get readIds => Set.unmodifiable(_readIds);

  Reminder reminderFor(String treatmentId) =>
      _reminders[treatmentId] ?? const Reminder(enabled: true);

  Future<void> updateReminder(String treatmentId, Reminder reminder) async {
    _reminders = {..._reminders, treatmentId: reminder};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _reminderKey,
      jsonEncode(_reminders.map((k, v) => MapEntry(k, v.toJson()))),
    );
    notifyListeners();
  }

  Future<void> snooze(String treatmentId, Duration duration) async {
    await updateReminder(
      treatmentId,
      Reminder(
        enabled: true,
        snoozedUntil: DateTime.now().add(duration),
      ),
    );
  }

  Future<void> markRead(Iterable<String> ids) async {
    _readIds = {..._readIds, ...ids};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readKey, jsonEncode(_readIds.toList()));
    notifyListeners();
  }

  bool isRead(String id) => _readIds.contains(id);

  bool isDone(String treatmentId) => _doneIds.contains(treatmentId);

  Future<void> markDone(String treatmentId) async {
    _doneIds = {..._doneIds, treatmentId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_doneKey, jsonEncode(_doneIds.toList()));
    notifyListeners();
  }

  /// Waktu pengingat berikutnya: waktu tunda bila ada, selain itu jadwal.
  DateTime nextReminderAt(Treatment treatment, DateTime now) =>
      reminderFor(treatment.id).snoozedUntil ?? treatment.dueAt(now);

  /// Perawatan yang belum selesai, diurutkan dari waktu terdekat.
  List<Treatment> upcoming({DateTime? now, int? limit}) {
    final reference = now ?? DateTime.now();
    final pending = [
      for (final t in treatments)
        if (!isDone(t.id)) t,
    ]..sort((a, b) =>
        nextReminderAt(a, reference).compareTo(nextReminderAt(b, reference)));
    return limit == null ? pending : pending.take(limit).toList();
  }
}

Map<String, Reminder> _decodeReminders(String? raw) {
  if (raw == null) return {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>? ?? {};
    return decoded.map(
      (k, v) => MapEntry(k, Reminder.fromJson(v as Map<String, dynamic>)),
    );
  } catch (_) {
    return {};
  }
}
