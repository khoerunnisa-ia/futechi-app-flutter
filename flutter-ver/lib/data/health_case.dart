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

class RecoveryRecord {
  const RecoveryRecord({
    required this.disease,
    required this.diagnosedAt,
    required this.recoveredAt,
    required this.duration,
    required this.treatments,
    required this.vet,
    required this.currentCondition,
    required this.notes,
  });

  final String disease;
  final String diagnosedAt;
  final String recoveredAt;
  final String duration;
  final List<String> treatments;
  final String vet;
  final String currentCondition;
  final String notes;
}

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
    this.recoveryRecord,
  });

  final String id;
  final String chickenId;
  final String cage;

  /// ISO-8601 timestamp with offset, e.g. 2026-10-12T08:15:00+07:00.
  final String detectedAt;
  final String date; // human-readable Indonesian date label
  final String time;
  final FeedingSession session;
  final CaseLevel level;
  final CaseStatus initialStatus;
  final String symptoms;
  final CaseImage image;
  final List<DiseasePossibility> possibilities; // always 3
  final RecoveryRecord? recoveryRecord;

  DiseasePossibility get topPossibility => possibilities.first;

  /// ISO date key (yyyy-MM-dd) derived from [detectedAt].
  String get dateKey =>
      detectedAt.length >= 10 ? detectedAt.substring(0, 10) : detectedAt;
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

  factory SuspicionResult.fromJson(Map<String, dynamic> json) =>
      SuspicionResult(
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

/// Dummy data:
/// - 1 Menunggu Konfirmasi (paling lama 2 minggu terakhir)
/// - 2 Sakit (paling lama 1 bulan terakhir)
/// - 1 Sudah Sehat (dengan detail riwayat penyakit, diagnosa, tanggal sembuh, penanganan)
const List<HealthCase> healthCases = [
  HealthCase(
    id: 'a24',
    chickenId: 'AYM-A3-23',
    cage: 'Sangkar A3-24',
    detectedAt: '2026-10-12T08:15:00+07:00',
    date: '10 Oktober 2026',
    time: '08:15',
    session: FeedingSession.morning,
    level: CaseLevel.peringatan,
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
      DiseasePossibility(
          name: 'Infectious Bronchitis',
          confidence: 72,
          symptoms: [
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
    chickenId: 'AYM-C1-02',
    cage: 'Sangkar C1-02',
    detectedAt: '2026-10-08T17:10:00+07:00',
    date: '2 Oktober 2026',
    time: '17:10',
    session: FeedingSession.evening,
    level: CaseLevel.kritis,
    initialStatus: CaseStatus.sick,
    symptoms:
        'Ayam tampak lesu, lebih banyak diam, dan pola makan berubah drastis dibanding kelompoknya.',
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
    chickenId: 'AYM-B2-05',
    cage: 'Sangkar B2-05',
    detectedAt: '2026-09-26T17:06:00+07:00',
    date: '26 September 2026',
    time: '17:06',
    session: FeedingSession.evening,
    level: CaseLevel.kritis,
    initialStatus: CaseStatus.sick,
    symptoms:
        'Napas lebih cepat, sayap terbuka, dan aktivitas makan menurun drastis setelah suhu kandang naik.',
    image: CaseImage.evening,
    possibilities: [
      DiseasePossibility(name: 'Heat Stress Akut', confidence: 88, symptoms: [
        'Napas cepat terengah-engah',
        'Sayap terkulai terbuka',
        'Banyak minum berlebihan',
        'Aktivitas makan anjlok',
      ]),
      DiseasePossibility(name: 'Dehidrasi Berat', confidence: 71, symptoms: [
        'Lesu terbaring',
        'Kulit kaki kering pucat',
        'Berat badan turun drastis',
      ]),
      DiseasePossibility(
          name: 'Infeksi Saluran Pernapasan',
          confidence: 49,
          symptoms: [
            'Batuk atau bersin',
            'Napas berbunyi',
            'Cairan dari hidung',
          ]),
    ],
  ),
  HealthCase(
    id: 'd12',
    chickenId: 'AYM-D1-07',
    cage: 'Sangkar D1-07',
    detectedAt: '2026-09-22T08:09:00+07:00',
    date: '22 September 2026',
    time: '08:09',
    session: FeedingSession.morning,
    level: CaseLevel.peringatan,
    initialStatus: CaseStatus.healthy,
    symptoms:
        'Riwayat: Aktivitas makan sempat menurun, feses encer, dan postur terlihat kurang aktif selama pengamatan pagi.',
    image: CaseImage.morning,
    possibilities: [
      DiseasePossibility(
          name: 'Gangguan Saluran Pernapasan & Malnutrisi Ringan',
          confidence: 82,
          symptoms: [
            'Nafsu makan menurun',
            'Feses berubah',
            'Berat badan turun',
            'Gerak melambat',
          ]),
      DiseasePossibility(name: 'Heat Stress Ringan', confidence: 45, symptoms: [
        'Napas cepat',
        'Sayap terbuka',
        'Banyak minum',
      ]),
      DiseasePossibility(name: 'Dehidrasi Awal', confidence: 32, symptoms: [
        'Lesu',
        'Kulit kaki kering',
      ]),
    ],
    recoveryRecord: RecoveryRecord(
      disease: 'Gangguan Saluran Pernapasan & Malnutrisi Ringan',
      diagnosedAt: '22 Agustus 2026, 08:09 WIB',
      recoveredAt: '12 Oktober 2026, 11:30 WIB',
      duration: '21 Hari Masa Perawatan & Karantina',
      treatments: [
        'Isolasi 14 hari di kandang observasi berpendingin & ventilasi terpisah',
        'Pemberian antibiotik pernapasan Enrofloxacin dosis 10 mg/kg BB selama 5 hari',
        'Pemberian multivitamin Vita-Stress & larutan elektrolit pada air minum harian',
        'Disinfeksi sangkar D-12 secara berkala 2 hari sekali dengan antiseptik kandang',
        'Pemberian pakan konsentrat basah berprotein tinggi untuk memulihkan bobot tubuh',
      ],
      vet: 'drh. Hendra Setiawan, Sp.Unggas',
      currentCondition:
          'Kondisi saat ini: Bobot badan naik +240 gram (kembali ke batas ideal), pernapasan bersih tanpa ronkhi, nafsu makan pulih 100%, gerak lincah dan mata cerah. Telah dikembalikan ke kandang utama D-12 dan aman berbaur dengan populasi.',
      notes:
          'Observasi pasca-karantina selama 7 hari menunjukkan hasil bebas gejala klinis. Ayam telah dinyatakan sembuh total dengan sistem kekebalan tubuh yang stabil.',
    ),
  ),
];

final List<HealthCase> sortedHealthCases = [...healthCases]..sort((a, b) {
    const levelWeight = {CaseLevel.kritis: 0, CaseLevel.peringatan: 1};
    final byLevel = levelWeight[a.level]! - levelWeight[b.level]!;
    if (byLevel != 0) return byLevel;
    return b.detectedAt.compareTo(a.detectedAt);
  });

final HealthCase defaultHealthCase = healthCases.first;

HealthCase getHealthCase(String caseId) => healthCases
    .firstWhere((c) => c.id == caseId, orElse: () => defaultHealthCase);

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
