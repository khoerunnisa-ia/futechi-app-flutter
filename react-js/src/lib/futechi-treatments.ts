import { useCallback, useEffect, useState } from "react";

export type Treatment = {
  id: string;
  name: string;
  schedule: string;
  dueLabel: string;
  target: string;
  status: "Mendesak" | "Terjadwal";
  product: string;
  ingredient: string;
  form: string;
  dosage: string;
  safety: string;
  steps: string[];
  buyUrl: string;
  tutorialUrl: string;
};

export const treatments: Treatment[] = [
  {
    id: "vaksin-nd",
    name: "Vaksinasi ND-Gumboro",
    schedule: "Hari ini, 08:00 WIB",
    dueLabel: "Hari ini",
    target: "Batch #24",
    status: "Mendesak",
    product: "Vaksin ND-IB Aktif (contoh)",
    ingredient: "Virus Newcastle Disease & Gumboro hidup dilemahkan",
    form: "Serbuk beku kering + pelarut, tetes mata/air minum",
    dosage: "1 dosis per ekor sesuai label produk dan arahan dokter hewan.",
    safety:
      "Gunakan vaksin dari pemasok resmi, simpan 2–8°C, jangan dicampur desinfektan. Konsultasikan dokter hewan sebelum aplikasi.",
    steps: [
      "Puasakan air minum ayam 1–2 jam sebelum vaksinasi.",
      "Larutkan vaksin dengan pelarut dingin sesuai jumlah ayam.",
      "Berikan melalui tetes mata atau air minum yang bersih tanpa klorin.",
      "Pastikan seluruh larutan habis dalam 2 jam.",
      "Catat waktu, batch, dan reaksi ayam setelah vaksinasi.",
    ],
    buyUrl: "https://www.tokopedia.com/search?q=vaksin%20ND%20ayam",
    tutorialUrl: "https://www.youtube.com/results?search_query=cara+vaksin+ND+ayam",
  },
  {
    id: "vitamin-a",
    name: "Pemberian Vitamin A",
    schedule: "Dalam 3 hari, 07:30 WIB",
    dueLabel: "Dalam 3 hari",
    target: "Batch #24",
    status: "Terjadwal",
    product: "Multivitamin Unggas Larut Air (contoh)",
    ingredient: "Vitamin A, D3, E, dan elektrolit",
    form: "Serbuk larut air",
    dosage: "Sesuai takaran pada label per liter air minum; ikuti arahan dokter hewan.",
    safety: "Jangan melebihi takaran label. Hentikan dan konsultasikan bila ayam tampak lemas.",
    steps: [
      "Siapkan air minum bersih sesuai kebutuhan harian.",
      "Larutkan vitamin sesuai takaran label.",
      "Isi tempat minum dan pastikan semua ayam mendapat akses.",
      "Ganti dengan air baru setelah 6–8 jam.",
    ],
    buyUrl: "https://www.tokopedia.com/search?q=vitamin%20ayam%20larut%20air",
    tutorialUrl: "https://www.youtube.com/results?search_query=cara+memberi+vitamin+ayam",
  },
  {
    id: "sanitasi",
    name: "Pembersihan Kandang",
    schedule: "Dalam 5 hari, 09:00 WIB",
    dueLabel: "Dalam 5 hari",
    target: "Batch #24",
    status: "Terjadwal",
    product: "Desinfektan Kandang (contoh)",
    ingredient: "Senyawa amonium kuartener",
    form: "Cairan konsentrat untuk semprot",
    dosage: "Encerkan sesuai petunjuk label untuk penyemprotan kandang.",
    safety: "Gunakan masker, sarung tangan, dan kacamata. Jangan menyemprot langsung ke ayam.",
    steps: [
      "Keluarkan sisa pakan dan litter kotor.",
      "Cuci lantai dan peralatan dengan air dan sabun.",
      "Semprot desinfektan secara merata.",
      "Biarkan kering dan ventilasi terbuka sebelum ayam kembali.",
    ],
    buyUrl: "https://www.tokopedia.com/search?q=desinfektan%20kandang%20ayam",
    tutorialUrl: "https://youtu.be/IKJHTVASQRo?si=4-lJRPaIVqMUip29",
  },
];

export function getTreatment(id: string) {
  return treatments.find((t) => t.id === id);
}

const REMINDER_KEY = "futechi-reminders-v1";
const READ_KEY = "futechi-notif-read-v1";
const EVENT = "futechi-local-change";

export type Reminder = { enabled: boolean; snoozedUntil?: string };

function read<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  try {
    return (JSON.parse(localStorage.getItem(key) ?? "null") as T) ?? fallback;
  } catch {
    return fallback;
  }
}
function write(key: string, value: unknown) {
  localStorage.setItem(key, JSON.stringify(value));
  window.dispatchEvent(new CustomEvent(EVENT));
}

function useLocal<T>(key: string, fallback: T) {
  const [value, setValue] = useState<T>(fallback);
  const refresh = useCallback(() => setValue(read(key, fallback)), [key]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    refresh();
    window.addEventListener(EVENT, refresh);
    window.addEventListener("storage", refresh);
    return () => {
      window.removeEventListener(EVENT, refresh);
      window.removeEventListener("storage", refresh);
    };
  }, [refresh]);
  return [value, (next: T) => write(key, next)] as const;
}

export function useReminders() {
  return useLocal<Record<string, Reminder>>(REMINDER_KEY, {});
}
export function useReadNotifications() {
  return useLocal<string[]>(READ_KEY, []);
}
