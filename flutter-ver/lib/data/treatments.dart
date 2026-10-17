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
    id: 'vaksin-nd',
    name: 'Vaksinasi ND-Gumboro',
    schedule: 'Hari ini, 08:00 WIB',
    dueLabel: 'Hari ini',
    dueInDays: 0,
    dueHour: 8,
    dueMinute: 0,
    target: 'Batch #24',
    status: TreatmentStatus.mendesak,
    product: 'Vaksin ND-IB Aktif (contoh)',
    ingredient: 'Virus Newcastle Disease & Gumboro hidup dilemahkan',
    form: 'Serbuk beku kering + pelarut, tetes mata/air minum',
    dosage: '1 dosis per ekor sesuai label produk dan arahan dokter hewan.',
    safety:
        'Gunakan vaksin dari pemasok resmi, simpan 2–8°C, jangan dicampur desinfektan. Konsultasikan dokter hewan sebelum aplikasi.',
    steps: [
      'Puasakan air minum ayam 1–2 jam sebelum vaksinasi.',
      'Larutkan vaksin dengan pelarut dingin sesuai jumlah ayam.',
      'Berikan melalui tetes mata atau air minum yang bersih tanpa klorin.',
      'Pastikan seluruh larutan habis dalam 2 jam.',
      'Catat waktu, batch, dan reaksi ayam setelah vaksinasi.',
    ],
    buyUrl: 'https://www.tokopedia.com/search?q=vaksin%20ND%20ayam',
    tutorialUrl: 'https://www.youtube.com/results?search_query=cara+vaksin+ND+ayam',
  ),
  Treatment(
    id: 'vitamin-a',
    name: 'Pemberian Vitamin A',
    schedule: 'Dalam 3 hari, 07:30 WIB',
    dueLabel: 'Dalam 3 hari',
    dueInDays: 3,
    dueHour: 7,
    dueMinute: 30,
    target: 'Batch #24',
    status: TreatmentStatus.terjadwal,
    product: 'Multivitamin Unggas Larut Air (contoh)',
    ingredient: 'Vitamin A, D3, E, dan elektrolit',
    form: 'Serbuk larut air',
    dosage: 'Sesuai takaran pada label per liter air minum; ikuti arahan dokter hewan.',
    safety:
        'Jangan melebihi takaran label. Hentikan dan konsultasikan bila ayam tampak lemas.',
    steps: [
      'Siapkan air minum bersih sesuai kebutuhan harian.',
      'Larutkan vitamin sesuai takaran label.',
      'Isi tempat minum dan pastikan semua ayam mendapat akses.',
      'Ganti dengan air baru setelah 6–8 jam.',
    ],
    buyUrl: 'https://www.tokopedia.com/search?q=vitamin%20ayam%20larut%20air',
    tutorialUrl: 'https://www.youtube.com/results?search_query=cara+memberi+vitamin+ayam',
  ),
  Treatment(
    id: 'sanitasi',
    name: 'Pembersihan Kandang',
    schedule: 'Dalam 5 hari, 09:00 WIB',
    dueLabel: 'Dalam 5 hari',
    dueInDays: 5,
    dueHour: 9,
    dueMinute: 0,
    target: 'Batch #24',
    status: TreatmentStatus.terjadwal,
    product: 'Desinfektan Kandang (contoh)',
    ingredient: 'Senyawa amonium kuartener',
    form: 'Cairan konsentrat untuk semprot',
    dosage: 'Encerkan sesuai petunjuk label untuk penyemprotan kandang.',
    safety:
        'Gunakan masker, sarung tangan, dan kacamata. Jangan menyemprot langsung ke ayam.',
    steps: [
      'Keluarkan sisa pakan dan litter kotor.',
      'Cuci lantai dan peralatan dengan air dan sabun.',
      'Semprot desinfektan secara merata.',
      'Biarkan kering dan ventilasi terbuka sebelum ayam kembali.',
    ],
    buyUrl: 'https://www.tokopedia.com/search?q=desinfektan%20kandang%20ayam',
    tutorialUrl: 'https://youtu.be/IKJHTVASQRo?si=4-lJRPaIVqMUip29',
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
