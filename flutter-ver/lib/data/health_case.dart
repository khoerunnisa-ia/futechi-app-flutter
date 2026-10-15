/// Port of react-js/src/lib/futechi-cases.ts
library;

class DiseasePossibility {
  const DiseasePossibility({
    required this.name,
    required this.confidence,
    required this.symptoms,
  });

  final String name;
  final int confidence; // 0-100
  final List<String> symptoms;

  factory DiseasePossibility.fromJson(Map<String, dynamic> json) =>
      DiseasePossibility(
        name: json['disease'] as String? ?? json['name'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toInt() ?? 0,
        symptoms: (json['symptoms'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
}

enum CaseStatus { pending, sick, healthy }

enum FeedingSession { morning, evening }

enum CaseLevel { kritis, peringatan }

enum CaseImage { sick, morning, evening, avian }

class HealthCase {
  const HealthCase({
    required this.id,
    required this.chickenId,
    required this.cage,
    required this.detectedAt,
    required this.date,
    required this.time,
    required this.session,
    required this.level,
    required this.initialStatus,
    required this.symptoms,
    required this.image,
    required this.possibilities,
  });

  final String id;
  final String chickenId;
  final String cage;
  /// ISO-8601 timestamp with offset, e.g. 2026-07-19T08:15:00+07:00.
  final String detectedAt;
  final String date; // human-readable Indonesian date label
  final String time;
  final FeedingSession session;
  final CaseLevel level;
  final CaseStatus initialStatus;
  final String symptoms;
  final CaseImage image;
  final List<DiseasePossibility> possibilities; // always 3

  DiseasePossibility get topPossibility => possibilities.first;

  /// ISO date key (yyyy-MM-dd) derived from [detectedAt].
  String get dateKey => detectedAt.length >= 10 ? detectedAt.substring(0, 10) : detectedAt;
}

class SuspicionResult {
  const SuspicionResult({
    required this.disease,
    required this.confidence,
    required this.rationale,
    required this.mitigation,
    required this.medication,
    required this.submittedAt,
  });

  final String disease;
  final int confidence; // 0-100
  final String rationale;
  final List<String> mitigation; // 3 practical actions
  final String medication;
  final String submittedAt; // ISO timestamp

  factory SuspicionResult.fromJson(Map<String, dynamic> json) => SuspicionResult(
        disease: json['disease'] as String,
        confidence: (json['confidence'] as num).toInt(),
        rationale: json['rationale'] as String,
        mitigation: (json['mitigation'] as List).whereType<String>().toList(),
        medication: json['medication'] as String,
        submittedAt: json['submittedAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'disease': disease,
        'confidence': confidence,
        'rationale': rationale,
        'mitigation': mitigation,
        'medication': medication,
        'submittedAt': submittedAt,
      };
}

const List<HealthCase> healthCases = [
  HealthCase(
    id: 'a24',
    chickenId: 'AYM-A3-23',
    cage: 'Sangkar A-24',
    detectedAt: '2026-07-19T08:15:00+07:00',
    date: '19 Juli 2026',
    time: '07:15',
    session: FeedingSession.morning,
    level: CaseLevel.kritis,
    initialStatus: CaseStatus.pending,
    symptoms:
        'Gerak melambat, nafsu makan berkurang, dan posisi kepala terpantau tidak stabil.',
    image: CaseImage.sick,
    possibilities: [
      DiseasePossibility(name: 'Newcastle Disease', confidence: 94, symptoms: [
        'Gerak melambat',
        'Nafsu makan berkurang',
        'Kepala tidak stabil',
        'Gangguan pernapasan',
      ]),
      DiseasePossibility(name: 'Infectious Bronchitis', confidence: 72, symptoms: [
        'Batuk atau bersin',
        'Napas berbunyi',
        'Mata berair',
        'Produksi telur menurun',
      ]),
      DiseasePossibility(name: 'Avian Influenza', confidence: 58, symptoms: [
        'Lesu mendadak',
        'Jengger membiru',
        'Pembengkakan kepala',
        'Penurunan makan',
      ]),
    ],
  ),
  HealthCase(
    id: 'c9',
    chickenId: 'AYM-C09-02',
    cage: 'Sangkar C-9',
    detectedAt: '2026-07-18T17:10:00+07:00',
    date: '18 Juli 2026',
    time: '17:10',
    session: FeedingSession.evening,
    level: CaseLevel.kritis,
    initialStatus: CaseStatus.sick,
    symptoms:
        'Ayam tampak lesu, lebih banyak diam, dan pola makan berubah dibanding kelompoknya.',
    image: CaseImage.avian,
    possibilities: [
      DiseasePossibility(name: 'Avian Influenza', confidence: 91, symptoms: [
        'Lesu mendadak',
        'Jengger membiru',
        'Pembengkakan kepala',
        'Penurunan makan',
      ]),
      DiseasePossibility(name: 'Newcastle Disease', confidence: 76, symptoms: [
        'Gerak melambat',
        'Nafsu makan berkurang',
        'Kepala tidak stabil',
        'Gangguan pernapasan',
      ]),
      DiseasePossibility(name: 'Infectious Coryza', confidence: 54, symptoms: [
        'Wajah membengkak',
        'Cairan dari hidung',
        'Mata berair',
        'Napas berbunyi',
      ]),
    ],
  ),
  HealthCase(
    id: 'b5',
    chickenId: 'AYM-B05-05',
    cage: 'Sangkar B-5',
    detectedAt: '2026-07-19T17:06:00+07:00',
    date: '19 Juli 2026',
    time: '17:06',
    session: FeedingSession.evening,
    level: CaseLevel.peringatan,
    initialStatus: CaseStatus.pending,
    symptoms:
        'Napas lebih cepat, sayap terbuka, dan aktivitas makan menurun setelah suhu kandang naik.',
    image: CaseImage.evening,
    possibilities: [
      DiseasePossibility(name: 'Heat Stress', confidence: 86, symptoms: [
        'Napas cepat',
        'Sayap terbuka',
        'Banyak minum',
        'Aktivitas makan menurun',
      ]),
      DiseasePossibility(name: 'Dehidrasi', confidence: 69, symptoms: [
        'Lesu',
        'Kulit kaki kering',
        'Minum meningkat',
        'Berat badan turun',
      ]),
      DiseasePossibility(name: 'Infeksi Saluran Pernapasan', confidence: 47, symptoms: [
        'Batuk atau bersin',
        'Napas berbunyi',
        'Cairan dari hidung',
        'Mata berair',
      ]),
    ],
  ),
  HealthCase(
    id: 'd12',
    chickenId: 'AYM-D1-07',
    cage: 'Sangkar D-12',
    detectedAt: '2026-07-18T08:09:00+07:00',
    date: '18 Juli 2026',
    time: '08:09',
    session: FeedingSession.morning,
    level: CaseLevel.peringatan,
    initialStatus: CaseStatus.healthy,
    symptoms:
        'Aktivitas makan sempat menurun dan postur terlihat kurang aktif selama pengamatan pagi.',
    image: CaseImage.morning,
    possibilities: [
      DiseasePossibility(name: 'Gangguan Pernapasan', confidence: 74, symptoms: [
        'Nafsu makan menurun',
        'Feses berubah',
        'Berat badan turun',
        'Gerak melambat',
      ]),
      DiseasePossibility(name: 'Heat Stress', confidence: 52, symptoms: [
        'Napas cepat',
        'Sayap terbuka',
        'Banyak minum',
        'Aktivitas makan menurun',
      ]),
      DiseasePossibility(name: 'Dehidrasi', confidence: 38, symptoms: [
        'Lesu',
        'Kulit kaki kering',
        'Minum meningkat',
        'Berat badan turun',
      ]),
    ],
  ),
];

final List<HealthCase> sortedHealthCases = [...healthCases]..sort((a, b) {
    const levelWeight = {CaseLevel.kritis: 0, CaseLevel.peringatan: 1};
    final byLevel = levelWeight[a.level]! - levelWeight[b.level]!;
    if (byLevel != 0) return byLevel;
    return b.detectedAt.compareTo(a.detectedAt);
  });

final HealthCase defaultHealthCase = healthCases.first;

HealthCase getHealthCase(String caseId) =>
    healthCases.firstWhere((c) => c.id == caseId, orElse: () => defaultHealthCase);

HealthCase? getCaseFromThreadId(String threadId) {
  if (!threadId.startsWith('alert-')) return null;
  return getHealthCase(threadId.substring('alert-'.length));
}

class CaseChecklistItem {
  const CaseChecklistItem(this.id, this.title, this.description);
  final String id;
  final String title;
  final String description;
}

const List<CaseChecklistItem> caseChecklist = [
  CaseChecklistItem(
    'isolate',
    'Pisahkan ayam untuk observasi',
    'Pindahkan ayam yang menunjukkan gejala ke area observasi dengan ventilasi baik.',
  ),
  CaseChecklistItem(
    'environment',
    'Periksa kondisi kandang',
    'Periksa air minum, suhu, kelembapan, dan sirkulasi udara di sekitar sangkar.',
  ),
  CaseChecklistItem(
    'record',
    'Catat perubahan kondisi',
    'Pantau nafsu makan dan gerak ayam, lalu hubungi dokter hewan bila kondisinya memburuk.',
  ),
];

String caseStatusLabel(CaseStatus status) {
  switch (status) {
    case CaseStatus.pending:
      return 'Menunggu Konfirmasi';
    case CaseStatus.sick:
      return 'Sakit';
    case CaseStatus.healthy:
      return 'Sudah Sehat';
  }
}
