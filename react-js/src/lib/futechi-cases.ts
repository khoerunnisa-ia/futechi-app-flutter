export type DiseasePossibility = {
  name: string;
  confidence: number;
  symptoms: string[];
};

export type CaseStatus = "pending" | "sick" | "healthy";
export type FeedingSession = "morning" | "evening";

export type HealthCase = {
  id: string;
  chickenId: string;
  cage: string;
  detectedAt: string;
  date: string;
  time: string;
  session: FeedingSession;
  level: "Kritis" | "Peringatan";
  initialStatus: CaseStatus;
  symptoms: string;
  image: "sick" | "morning" | "evening" | "avian";
  possibilities: [DiseasePossibility, DiseasePossibility, DiseasePossibility];
};

export type SuspicionResult = {
  disease: string;
  confidence: number;
  rationale: string;
  mitigation: string[];
  medication: string;
  submittedAt: string;
};

export const healthCases: HealthCase[] = [
  {
    id: "a24",
    chickenId: "AYM-A3-23",
    cage: " ",
    detectedAt: "2026-07-19T08:15:00+07:00",
    date: "19 Juli 2026",
    time: "07:15",
    session: "morning",
    level: "Kritis",
    initialStatus: "pending",
    symptoms: "Gerak melambat, nafsu makan berkurang, dan posisi kepala terpantau tidak stabil.",
    image: "sick",
    possibilities: [
      {
        name: "Newcastle Disease",
        confidence: 94,
        symptoms: ["Gerak melambat", "Nafsu makan berkurang", "Kepala tidak stabil", "Gangguan pernapasan"],
      },
      {
        name: "Infectious Bronchitis",
        confidence: 72,
        symptoms: ["Batuk atau bersin", "Napas berbunyi", "Mata berair", "Produksi telur menurun"],
      },
      {
        name: "Avian Influenza",
        confidence: 58,
        symptoms: ["Lesu mendadak", "Jengger membiru", "Pembengkakan kepala", "Penurunan makan"],
      },
    ],
  },
  {
    id: "c9",
    chickenId: "AYM-C09-02",
    cage: " ",
    detectedAt: "2026-07-18T17:10:00+07:00",
    date: "18 Juli 2026",
    time: "17:10",
    session: "evening",
    level: "Kritis",
    initialStatus: "sick",
    symptoms: "Ayam tampak lesu, lebih banyak diam, dan pola makan berubah dibanding kelompoknya.",
    image: "avian",
    possibilities: [
      {
        name: "Avian Influenza",
        confidence: 91,
        symptoms: ["Lesu mendadak", "Jengger membiru", "Pembengkakan kepala", "Penurunan makan"],
      },
      {
        name: "Newcastle Disease",
        confidence: 76,
        symptoms: ["Gerak melambat", "Nafsu makan berkurang", "Kepala tidak stabil", "Gangguan pernapasan"],
      },
      {
        name: "Infectious Coryza",
        confidence: 54,
        symptoms: ["Wajah membengkak", "Cairan dari hidung", "Mata berair", "Napas berbunyi"],
      },
    ],
  },
  {
    id: "b5",
    chickenId: "AYM-B05-05",
    cage: " ",
    detectedAt: "2026-07-19T17:06:00+07:00",
    date: "19 Juli 2026",
    time: "17:06",
    session: "evening",
    level: "Peringatan",
    initialStatus: "pending",
    symptoms: "Napas lebih cepat, sayap terbuka, dan aktivitas makan menurun setelah suhu kandang naik.",
    image: "evening",
    possibilities: [
      {
        name: "Heat Stress",
        confidence: 86,
        symptoms: ["Napas cepat", "Sayap terbuka", "Banyak minum", "Aktivitas makan menurun"],
      },
      {
        name: "Dehidrasi",
        confidence: 69,
        symptoms: ["Lesu", "Kulit kaki kering", "Minum meningkat", "Berat badan turun"],
      },
      {
        name: "Infeksi Saluran Pernapasan",
        confidence: 47,
        symptoms: ["Batuk atau bersin", "Napas berbunyi", "Cairan dari hidung", "Mata berair"],
      },
    ],
  },
  {
    id: "d12",
    chickenId: "AYM-D1-07",
    cage: " ",
    detectedAt: "2026-07-18T08:09:00+07:00",
    date: "18 Juli 2026",
    time: "08:09",
    session: "morning",
    level: "Peringatan",
    initialStatus: "healthy",
    symptoms: "Aktivitas makan sempat menurun dan postur terlihat kurang aktif selama pengamatan pagi.",
    image: "morning",
    possibilities: [
      {
        name: "Gangguan Pernapasan",
        confidence: 74,
        symptoms: ["Nafsu makan menurun", "Feses berubah", "Berat badan turun", "Gerak melambat"],
      },
      {
        name: "Heat Stress",
        confidence: 52,
        symptoms: ["Napas cepat", "Sayap terbuka", "Banyak minum", "Aktivitas makan menurun"],
      },
      {
        name: "Dehidrasi",
        confidence: 38,
        symptoms: ["Lesu", "Kulit kaki kering", "Minum meningkat", "Berat badan turun"],
      },
    ],
  },
];

const levelWeight = { Kritis: 0, Peringatan: 1 } as const;

export const sortedHealthCases = [...healthCases].sort(
  (a, b) => levelWeight[a.level] - levelWeight[b.level] || b.detectedAt.localeCompare(a.detectedAt),
);

export const defaultHealthCase = healthCases[0] as HealthCase;

export function getHealthCase(caseId: string) {
  return healthCases.find((item) => item.id === caseId) ?? defaultHealthCase;
}

export function getCaseFromThreadId(threadId: string) {
  if (!threadId.startsWith("alert-")) return undefined;
  return getHealthCase(threadId.slice("alert-".length));
}

export function caseDateKey(item: HealthCase) {
  return item.detectedAt.slice(0, 10);
}

export const caseChecklist = [
  {
    id: "isolate",
    title: "Pisahkan ayam untuk observasi",
    description: "Pindahkan ayam yang menunjukkan gejala ke area observasi dengan ventilasi baik.",
  },
  {
    id: "environment",
    title: "Periksa kondisi kandang",
    description: "Periksa air minum, suhu, kelembapan, dan sirkulasi udara di sekitar sangkar.",
  },
  {
    id: "record",
    title: "Catat perubahan kondisi",
    description: "Pantau nafsu makan dan gerak ayam, lalu hubungi dokter hewan bila kondisinya memburuk.",
  },
] as const;
