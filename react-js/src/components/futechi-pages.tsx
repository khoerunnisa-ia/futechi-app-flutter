import { Link } from "@tanstack/react-router";
import {
  Activity,
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Camera,
  Check,
  ChevronRight,
  CircleUserRound,
  Clock3,
  Droplets,
  Egg,
  Expand,
  Gauge,
  HeartPulse,
  Languages,
  Leaf,
  LockKeyhole,
  LogOut,
  MapPin,
  Play,
  Plus,
  ShieldCheck,
  Thermometer,
  UtensilsCrossed,
  Video,
  Wheat,
  Wrench,
  X,
  type LucideIcon,
} from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import barn from "@/assets/futechi-barn.jpg";
import heroAsset from "@/assets/futechi-hero-chickens.jpg.asset.json";
import cctvAsset from "@/assets/cctv-kandang.jpg.asset.json";
import sickChicken from "@/assets/sick-chicken-feeding.jpg";
import feedingMorningAsset from "@/assets/chickens-feeding-morning.jpg.asset.json";
import feedingEveningAsset from "@/assets/chickens-feeding-evening.jpg.asset.json";
import avianAsset from "@/assets/avian-influenza.jpg.asset.json";
import techi from "@/assets/techi-mascot.png";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { treatments as treatmentList } from "@/lib/futechi-treatments";
import { caseStatusLabel, useCaseState, useCaseStatuses } from "@/lib/futechi-case-state";
import {
  caseDateKey,
  defaultHealthCase,
  getHealthCase,
  sortedHealthCases,
  type CaseStatus,
  type FeedingSession,
  type HealthCase,
} from "@/lib/futechi-cases";

const card =
  "rounded-[20px] border border-border/70 bg-card shadow-[0_8px_28px_color-mix(in_oklab,var(--foreground)_7%,transparent)]";
function PageTitle({ title, description, action }: { title: string; description: string; action?: React.ReactNode }) {
  return (
    <div className="mb-6 grid grid-cols-[minmax(0,1fr)_auto] items-start gap-4">
      <div className="min-w-0">
        <h1 className="text-2xl font-bold sm:text-3xl">{title}</h1>
        <p className="mt-1 text-sm text-muted-foreground sm:text-base">{description}</p>
      </div>
      {action}
    </div>
  );
}
function Section({ title, children, action }: { title: string; children: React.ReactNode; action?: React.ReactNode }) {
  return (
    <section>
      <div className="mb-4 flex items-center justify-between gap-4">
        <h2 className="text-xl font-bold sm:text-2xl">{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

const sensorCards = [
  {
    name: "Suhu",
    value: "31.2°C",
    note: "Rentang ideal 28–32°C",
    delta: "↑ 0.8°C dari kemarin",
    icon: Thermometer,
    tone: "bg-danger-soft text-destructive",
  },
  {
    name: "Kelembapan",
    value: "71%",
    note: "Rentang ideal 60–75%",
    delta: "↑ 2% dari kemarin",
    icon: Droplets,
    tone: "bg-secondary text-primary",
  },
  {
    name: "Amonia",
    value: "5 ppm",
    note: "Aman di bawah 20 ppm",
    delta: "↓ 1 ppm dari kemarin",
    icon: Leaf,
    tone: "bg-success-soft text-success",
  },
];
const dailyCards: Array<{ icon: LucideIcon; value: string; label: string }> = [
  { icon: Egg, value: "1970", label: "Telur diproduksi" },
  { icon: HeartPulse, value: "99.3%", label: "Ayam sehat" },
  { icon: Activity, value: "3", label: "Anomali" },
  { icon: Wheat, value: "60 ton", label: "Pakan terpakai" },
];
const caseImages = {
  sick: sickChicken,
  morning: feedingMorningAsset.url,
  evening: feedingEveningAsset.url,
  avian: avianAsset.url,
} as const;

function StatusBadge({ status }: { status: CaseStatus }) {
  const tone =
    status === "sick"
      ? "bg-danger-soft text-destructive"
      : status === "healthy"
        ? "bg-success-soft text-success"
        : "bg-warning-soft text-warning";
  return (
    <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-bold ${tone}`}>{caseStatusLabel[status]}</span>
  );
}

function CaseCard({ item, status, imageTop = false }: { item: HealthCase; status: CaseStatus; imageTop?: boolean }) {
  const levelTone = item.level === "Kritis" ? "border-destructive text-destructive" : "border-warning text-warning";
  if (imageTop) {
    return (
      <Link
        to="/history/consultation/$alertId"
        params={{ alertId: item.id }}
        className={`${card} overflow-hidden transition hover:border-primary`}
      >
        <img
          src={caseImages[item.image]}
          alt={`Ayam ${item.chickenId} saat feeding`}
          width={1000}
          height={750}
          className="aspect-[4/3] w-full object-cover"
        />
        <div className="p-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="font-bold">{item.possibilities[0].name}</div>
              <div className="mt-1 text-xs text-muted-foreground">
                {item.date}, {item.time}
              </div>
            </div>
            <span className={`rounded-md border px-2 py-1 text-xs font-bold ${levelTone}`}>{item.level}</span>
          </div>
          <div className="mt-4 flex items-center justify-between gap-3 border-t border-border pt-3">
            <div>
              <div className="text-sm font-semibold">{item.chickenId}</div>
              <div className="text-xs text-muted-foreground">{item.cage}</div>
            </div>
            <StatusBadge status={status} />
          </div>
        </div>
      </Link>
    );
  }
  return (
    <Link
      to="/history/consultation/$alertId"
      params={{ alertId: item.id }}
      className={`${card} grid grid-cols-[80px_minmax(0,1fr)_auto] items-center gap-4 overflow-hidden border-l-4 p-3 transition hover:border-primary ${item.level === "Kritis" ? "border-l-destructive" : "border-l-warning"}`}
    >
      <img
        src={caseImages[item.image]}
        alt={`Ayam ${item.chickenId} terpantau saat makan`}
        loading="lazy"
        width={1000}
        height={750}
        className="size-20 rounded-xl object-cover"
      />
      <div className="min-w-0">
        <div className="font-bold">
          {item.chickenId}
        </div>
        <div className="mt-0.5 truncate text-sm text-muted-foreground">
          {item.possibilities[0].name} · Confidence {item.possibilities[0].confidence}%
        </div>
        <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
          <span>
            <b>Terdeteksi pada:</b> {item.date}, {item.time}
          </span>
          <StatusBadge status={status} />
        </div>
      </div>
      <span
        className={`flex items-center gap-1 text-xs font-bold ${item.level === "Kritis" ? "text-destructive" : "text-warning"}`}
      >
        {item.level}
        <ChevronRight className="size-4" />
      </span>
    </Link>
  );
}

function toDateKey(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function DashboardPage() {
  const [done, setDone] = useState(false);
  const [expanded, setExpanded] = useState(false);
  return (
    <div className="space-y-8">
      <section className="relative min-h-[310px] overflow-hidden rounded-[20px] bg-foreground">
        <img
          src={heroAsset.url}
          alt="Ayam sehat di dalam kandang modern Futechi"
          width={1400}
          height={700}
          className="absolute inset-0 size-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-r from-foreground/90 via-foreground/55 to-transparent" />
        <div className="relative flex min-h-[310px] max-w-xl flex-col justify-center p-7 text-background sm:p-10">
          <span className="mb-4 w-fit rounded-full bg-success px-3 py-1 text-xs font-bold text-success-foreground">
            ● Kondisi Baik
          </span>
          <h1 className="text-3xl font-bold sm:text-4xl">Pusat Informasi Peternakan</h1>
          <p className="mt-3 text-sm/6 text-background/85 sm:text-base">
            Monitoring real-time untuk peternakan yang lebih sehat dan produktif.
          </p>
          <p className="mt-7 flex items-center gap-2 text-xs text-background/80">
            <Clock3 className="size-4" /> Update terakhir: Hari ini, 07:41
          </p>
        </div>
      </section>
      <div className="grid gap-4 sm:grid-cols-3">
        {sensorCards.map(({ name, value, note, delta, icon: Icon, tone }) => (
          <div key={name} className={`${card} min-w-0 p-5`}>
            <div className="flex items-start justify-between gap-3">
              <div className={`grid size-12 shrink-0 place-items-center rounded-2xl ${tone}`}>
                <Icon />
              </div>
              <span className="text-right text-[11px] font-bold text-success">{delta}</span>
            </div>
            <div className="mt-4 text-sm font-semibold">{name}</div>
            <div className="text-2xl font-bold">{value}</div>
            <div className="mt-1 text-xs text-muted-foreground">{note}</div>
          </div>
        ))}
      </div>
      <div className={`${card} relative overflow-hidden`}>
        <img
          src={barn}
          alt="Visual isometrik Kandang 1"
          width={1408}
          height={912}
          className="aspect-[16/8.2] w-full object-cover"
        />
        <div className="absolute left-4 top-4 rounded-xl bg-card/95 p-3 shadow">
          <div className="font-bold">
            <span className="text-success">● Kandang Bendul Merisi</span>
          </div>
          <div className="text-xs text-muted-foreground">1,240 ekor ayam</div>
        </div>
        <div className="absolute right-[8%] top-[18%] rounded-xl bg-card/95 px-3 py-2 shadow">
          <div className="text-xs">Kelembapan</div>
          <strong>71%</strong>
        </div>
        <div className="absolute bottom-[16%] left-[32%] rounded-xl bg-card/95 px-3 py-2 shadow">
          <div className="text-xs">Suhu</div>
          <strong>31.2°C</strong>
        </div>
        <Button asChild className="absolute bottom-4 right-4 h-11 rounded-xl">
          <Link to="/history">
            Lihat detail <ArrowRight />
          </Link>
        </Button>
      </div>
      <div className="grid gap-6 lg:grid-cols-2">
        <div className={`${card} p-5`}>
          <Section
            title="Jadwal Feeding"
            action={
              <span className="rounded-full bg-warning-soft px-3 py-1 text-xs font-bold text-warning">Hari ini</span>
            }
          >
            <div className="divide-y divide-border">
              {[
                ["07:00", "Pagi", "Selesai"],
                ["16:00", "Sore", "Menunggu"],
              ].map((x) => (
                <div key={x[0]} className="grid grid-cols-[70px_1fr_auto] items-center gap-3 py-4">
                  <strong className="text-xl text-primary">{x[0]}</strong>
                  <div>
                    <div className="font-semibold">Pakan Grower</div>
                    <div className="text-xs text-muted-foreground">± 20 kg · Sesi {x[1]}</div>
                  </div>
                  <span className={x[2] === "Selesai" ? "text-success" : "text-muted-foreground"}>{x[2]}</span>
                </div>
              ))}
            </div>
            <Button
              onClick={() =>
                toast.success("Feeding dimulai", {
                  description: "Sistem Kandang 1 sedang menyalurkan 620 kg pakan.",
                })
              }
              className="mt-4 h-12 w-full rounded-xl"
            >
              <Play /> Jalankan Feeding Sekarang
            </Button>
          </Section>
        </div>
        <div className={`${card} overflow-hidden`}>
          <div className="flex items-center justify-between p-5">
            <div>
              <h2 className="text-xl font-bold">CCTV Pemantauan Kandang</h2>
              <p className="text-xs text-muted-foreground">Kualitas HD</p>
            </div>
            <span className="rounded-md bg-destructive px-2 py-1 text-xs font-bold text-destructive-foreground">
              ● LIVE
            </span>
          </div>
          <div className={`${expanded ? "fixed inset-0 z-50" : "relative"} bg-foreground`}>
            <div className="relative aspect-video size-full">
              <img src={cctvAsset.url} alt="Tayangan CCTV Kandang 1" className="size-full object-cover" />
              <div className="absolute inset-0 grid place-items-center bg-foreground/15">
                <div className="grid size-14 place-items-center rounded-full bg-card/85">
                  <Video className="text-primary" />
                </div>
              </div>
            </div>
            <Button
              onClick={() => setExpanded(!expanded)}
              variant="secondary"
              size="icon"
              className="absolute right-3 top-3"
            >
              <Expand />
            </Button>
          </div>
        </div>
      </div>
      <div className="grid gap-6 lg:grid-cols-[1.45fr_1fr]">
        <div>
          <Section title="Perawatan & Kesehatan">
            <div className={`${card} p-5`}>
              <Link
                to="/treatment/$treatmentId"
                params={{ treatmentId: "vaksin-nd" }}
                className="grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-4 rounded-xl transition-colors hover:bg-muted/40"
              >
                <div className="grid size-12 place-items-center rounded-2xl bg-danger-soft text-destructive">
                  <Wrench />
                </div>
                <div>
                  <div className="font-bold">Vaksinasi Newcastle Disease</div>
                  <div className="text-sm text-muted-foreground">Besok, 08:00 WIB</div>
                </div>
                <span className="rounded-md bg-danger-soft px-2 py-1 text-xs font-bold text-destructive">Mendesak</span>
              </Link>
              <Button
                disabled={done}
                onClick={() => {
                  setDone(true);
                  toast.success("Perawatan dikonfirmasi selesai");
                }}
                className="mt-4 h-11 w-full rounded-xl"
              >
                {done ? (
                  <>
                    <Check /> Selesai dikonfirmasi
                  </>
                ) : (
                  "Konfirmasi Selesai"
                )}
              </Button>
            </div>
          </Section>
        </div>
        <Section title="Ringkasan harian">
          <div className="grid grid-cols-2 gap-3">
            {dailyCards.map(({ icon: Icon, value, label }) => (
              <div key={label} className={`${card} p-4`}>
                <Icon className="mb-4 text-primary" />
                <div className="text-2xl font-bold">{value}</div>
                <div className="text-xs text-muted-foreground">{label}</div>
              </div>
            ))}
          </div>
        </Section>
      </div>
    </div>
  );
}

export function HistoryPage() {
  const statuses = useCaseStatuses(sortedHealthCases);
  const activeCases = sortedHealthCases.filter((item) => (statuses[item.id] ?? item.initialStatus) !== "healthy");
  const availableDates = [...new Set(sortedHealthCases.map(caseDateKey))];
  const [date, setDate] = useState<string | null>(null);
  const [draftDate, setDraftDate] = useState<string | null>(null);
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [session, setSession] = useState<"all" | FeedingSession>("all");
  const filteredCases = sortedHealthCases.filter(
    (item) => (date === null || caseDateKey(item) === date) && (session === "all" || item.session === session),
  );
  const selectedDate = date ? new Date(`${date}T12:00:00`) : null;
  const draftSelected = draftDate ? new Date(`${draftDate}T12:00:00`) : undefined;
  return (
    <div className="space-y-8">
      <PageTitle title="Riwayat Kesehatan" description="Analisis kamera dan anomali sensor peternakan" />
      <div className="grid gap-4 sm:grid-cols-3">
        {[
          ["Ayam dianalisis", "1,240", "100% populasi terpantau"],
          ["Ayam sehat", "1,237", "Skor kesehatan 92%"],
          ["Perlu perhatian", "3", "3 peringatan aktif"],
        ].map((x, i) => (
          <div className={`${card} p-5`} key={x[0]}>
            <div className="text-xs font-bold uppercase text-muted-foreground">{x[0]}</div>
            <div className={`mt-2 text-3xl font-bold ${i === 2 ? "text-destructive" : ""}`}>{x[1]}</div>
            <div className="mt-2 text-xs text-muted-foreground">{x[2]}</div>
          </div>
        ))}
      </div>
      <Section
        title="Status Kesehatan Aktif"
        action={
          <Button asChild variant="ghost">
            <Link to="/history/health-alerts">
              Lihat selengkapnya <ArrowRight />
            </Link>
          </Button>
        }
      >
        <div className="grid gap-3">
          {activeCases.slice(0, 3).map((item) => (
            <CaseCard key={item.id} item={item} status={statuses[item.id] ?? item.initialStatus} />
          ))}
        </div>
      </Section>
      <Section
        title="Riwayat Analisis Kesehatan"
        action={
          <div className="flex flex-wrap items-center justify-end gap-2">
            <div className="flex rounded-xl border border-border bg-card p-1">
              {(
                [
                  ["all", "Semua"],
                  ["morning", "Pagi"],
                  ["evening", "Sore"],
                ] as const
              ).map(([value, label]) => (
                <Button
                  key={value}
                  size="sm"
                  variant={session === value ? "default" : "ghost"}
                  onClick={() => setSession(value)}
                >
                  {label}
                </Button>
              ))}
            </div>
            <Popover
              open={calendarOpen}
              onOpenChange={(open) => {
                setCalendarOpen(open);
                if (open) setDraftDate(date);
              }}
            >
              <PopoverTrigger asChild>
                <Button variant="outline" size="icon" aria-label="Pilih tanggal analisis" className="relative">
                  <CalendarDays />
                  {date && <span className="absolute right-1 top-1 size-2 rounded-full bg-primary" />}
                </Button>
              </PopoverTrigger>
              <PopoverContent className="w-auto p-0" align="end">
                <Calendar
                  mode="single"
                  selected={draftSelected}
                  onSelect={(next) => setDraftDate(next ? toDateKey(next) : null)}
                  disabled={(day) => !availableDates.includes(toDateKey(day))}
                  className="pointer-events-auto p-3"
                />
                <div className="flex justify-end gap-2 border-t border-border p-3">
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => {
                      setDate(null);
                      setDraftDate(null);
                      setCalendarOpen(false);
                    }}
                  >
                    Reset
                  </Button>
                  <Button
                    size="sm"
                    onClick={() => {
                      setDate(draftDate);
                      setCalendarOpen(false);
                    }}
                  >
                    Terapkan
                  </Button>
                </div>
              </PopoverContent>
            </Popover>
          </div>
        }
      >
        <p className="mb-4 text-sm text-muted-foreground">
          {session === "all" ? "Semua sesi" : session === "morning" ? "Feeding pagi" : "Feeding sore"} ·{" "}
          {selectedDate
            ? selectedDate.toLocaleDateString("id-ID", { day: "numeric", month: "long", year: "numeric" })
            : "Semua tanggal"}
        </p>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filteredCases.map((item) => (
            <CaseCard key={item.id} item={item} status={statuses[item.id] ?? item.initialStatus} imageTop />
          ))}
        </div>
        {filteredCases.length === 0 && (
          <div className={`${card} p-8 text-center`}>
            <Camera className="mx-auto text-muted-foreground" />
            <h3 className="mt-3 font-bold">Tidak ada temuan</h3>
            <p className="mt-1 text-sm text-muted-foreground">Tidak ada ayam dengan temuan analisis pada waktu ini.</p>
          </div>
        )}
      </Section>
    </div>
  );
}

export function HealthAlertsPage() {
  const statuses = useCaseStatuses(sortedHealthCases);
  const activeCases = sortedHealthCases.filter((item) => (statuses[item.id] ?? item.initialStatus) !== "healthy");
  const waiting = activeCases.filter((item) => (statuses[item.id] ?? item.initialStatus) === "pending").length;
  const sick = activeCases.filter((item) => (statuses[item.id] ?? item.initialStatus) === "sick").length;
  return (
    <div className="space-y-7">
      <Button asChild variant="ghost">
        <Link to="/history">
          <ArrowLeft /> Kembali ke History
        </Link>
      </Button>
      <PageTitle title="Kasus Kesehatan Aktif" description="Ayam sakit dan temuan yang masih menunggu konfirmasi" />
      <div className="grid grid-cols-2 gap-4">
        <div className={`${card} p-5`}>
          <div className="text-xs font-bold uppercase text-muted-foreground">Menunggu Konfirmasi</div>
          <div className="mt-2 text-3xl font-bold text-warning">{waiting}</div>
        </div>
        <div className={`${card} p-5`}>
          <div className="text-xs font-bold uppercase text-muted-foreground">Sakit</div>
          <div className="mt-2 text-3xl font-bold text-destructive">{sick}</div>
        </div>
      </div>
      <div className="grid gap-3">
        {activeCases.map((item) => (
          <CaseCard key={item.id} item={item} status={statuses[item.id] ?? item.initialStatus} />
        ))}
      </div>
    </div>
  );
}

export function ConsultationPage({ alertId }: { alertId: string }) {
  const current = getHealthCase(alertId) ?? defaultHealthCase;
  const { status, setStatus, suspicionResult } = useCaseState(current);
  return (
    <div className="space-y-6">
      <Button asChild variant="ghost">
        <Link to="/history">
          <ArrowLeft /> Kembali ke History
        </Link>
      </Button>
      <PageTitle title="Konsultasi Peringatan" description={`${current.cage} · Terdeteksi ${current.date}`} />
      <div className="grid gap-6 lg:grid-cols-[1fr_1.15fr]">
        <div className={`${card} overflow-hidden`}>
          <img
            src={sickChicken}
            alt={`Ayam di ${current.cage} tampak depan saat makan`}
            width={1000}
            height={750}
            className="aspect-[4/3] w-full object-cover"
          />
          <div className="p-5">
            <StatusBadge status={status} />
            <h2 className="mt-4 text-2xl font-bold">{current.cage}</h2>
            <p className="mt-2 text-sm text-muted-foreground">{current.symptoms}</p>
            <div className="mt-5 grid grid-cols-2 gap-3">
              <Button onClick={() => setStatus("sick")} variant={status === "sick" ? "destructive" : "outline"}>
                {status === "sick" ? <Check /> : null} Konfirmasi Sakit
              </Button>
              <Button onClick={() => setStatus("healthy")} variant={status === "healthy" ? "default" : "outline"}>
                {status === "healthy" ? <Check /> : null} Tandai Sehat
              </Button>
            </div>
            {status !== "pending" && (
              <p className="mt-3 text-center text-sm font-semibold text-success">
                Status tersimpan: {caseStatusLabel[status]}
              </p>
            )}
          </div>
        </div>
        <div className="space-y-5">
          <div className={`${card} p-5`}>
            <div className="flex gap-3">
              <img src={techi} alt="Techi AI" className="size-12 object-contain" />
              <div>
                <h2 className="text-xl font-bold">Kemungkinan dari Analisis Visual</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Hasil ini bukan diagnosis pasti. Konfirmasi dengan pemeriksaan dokter hewan.
                </p>
              </div>
            </div>
            {suspicionResult ? (
              <div className="mt-5 space-y-4">
                <div className="rounded-xl border border-success bg-success-soft p-4">
                  <div className="text-xs font-bold uppercase text-success">Hasil pemeriksaan gejala</div>
                  <div className="mt-1 text-xl font-bold">{suspicionResult.disease}</div>
                  <div className="mt-1 text-sm text-success">Kecocokan {suspicionResult.confidence}%</div>
                  <p className="mt-3 text-sm">{suspicionResult.rationale}</p>
                </div>
                <div>
                  <h3 className="font-bold">Cara mitigasi</h3>
                  <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-muted-foreground">
                    {suspicionResult.mitigation.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </div>
                <div className="rounded-xl bg-warning-soft p-4">
                  <h3 className="font-bold text-warning">Saran obat/penanganan</h3>
                  <p className="mt-2 text-sm text-muted-foreground">{suspicionResult.medication}</p>
                </div>
              </div>
            ) : (
              <div className="mt-5 space-y-3">
                {current.possibilities.map((possibility, index) => (
                  <div
                    key={possibility.name}
                    className={`grid grid-cols-[auto_1fr_auto] items-center gap-3 rounded-xl border p-4 ${index === 0 ? "border-primary bg-secondary/60" : "border-border bg-muted/40"}`}
                  >
                    <span
                      className={`grid size-8 place-items-center rounded-full text-sm font-bold ${index === 0 ? "bg-primary text-primary-foreground" : "bg-card text-muted-foreground"}`}
                    >
                      {index + 1}
                    </span>
                    <div>
                      <div className="font-bold">{possibility.name}</div>
                      <progress
                        value={possibility.confidence}
                        max="100"
                        aria-label={`Confidence ${possibility.name}`}
                        className="mt-2 h-1.5 w-full accent-primary"
                      />
                    </div>
                    <strong className={index === 0 ? "text-primary" : "text-muted-foreground"}>
                      {possibility.confidence}%
                    </strong>
                  </div>
                ))}
              </div>
            )}
          </div>
          <div className={`${card} p-5`}>
            <h2 className="text-xl font-bold">Langkah Berikutnya</h2>
            <p className="mt-2 text-sm/7 text-muted-foreground">
              Buka konsultasi Techi untuk meninjau checklist observasi dan mencatat tindakan pada kasus ini.
            </p>
            <Button asChild className="mt-5 w-full">
              <Link to="/techi/$threadId" params={{ threadId: `alert-${current.id}` }}>
                Lanjutkan dengan Techi AI <ArrowRight />
              </Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function FeedingAnalysisPage({ analysisId }: { analysisId: string }) {
  return <ConsultationPage alertId={analysisId} />;
}

export function ReportPage() {
  return <FeedingAnalysisPage analysisId="a24" />;
}

export function FeedingPage() {
  const [items, setItems] = useState([
    { t: "06:00", n: "Sesi Pagi", on: false },
    { t: "7:00", n: "Sesi Pagi", on: true },
    { t: "16:30", n: "Sesi Sore", on: true },
    { t: "17:00", n: "Sesi Sore", on: false },
  ]);
  const add = () => {
    setItems((v) => [...v, { t: "22:00", n: "Sesi Tambahan", on: true }]);
    toast.success("Jadwal baru ditambahkan");
  };
  return (
    <div>
      <PageTitle
        title="Jadwal Pakan Otomatis"
        description="Atur sesi feeding Kandang"
        action={
          <Button
            onClick={() =>
              toast.success("Feeding berhasil dimulai", {
                description: "Pakan sedang disalurkan ke Kandang.",
              })
            }
            className="rounded-xl"
          >
            <UtensilsCrossed /> Beri Pakan Sekarang
          </Button>
        }
      />
      <div className="grid gap-4 sm:grid-cols-2">
        {items.map((x, i) => (
          <div className={`${card} grid grid-cols-[minmax(0,1fr)_auto] items-center p-6`} key={`${x.t}-${i}`}>
            <div>
              <div className={x.on ? "text-4xl font-bold" : "text-4xl font-bold text-muted-foreground"}>{x.t}</div>
              <div className="mt-2 text-sm text-muted-foreground">{x.n}</div>
            </div>
            <Button
              role="switch"
              aria-checked={x.on}
              onClick={() => setItems((v) => v.map((a, j) => (j === i ? { ...a, on: !a.on } : a)))}
              aria-label={`${x.on ? "Nonaktifkan" : "Aktifkan"} ${x.n}`}
              size="icon"
              variant={x.on ? "default" : "secondary"}
              className="rounded-full"
            >
              <Check className={x.on ? "opacity-100" : "opacity-0"} />
            </Button>
          </div>
        ))}
      </div>
      <Button onClick={add} variant="outline" className="mt-6 h-14 w-full rounded-xl border-primary text-primary">
        <Plus /> Tambah Jadwal
      </Button>
    </div>
  );
}

export function TreatmentPage() {
  return (
    <div className="space-y-8">
      <PageTitle
        title="Treatment & Batch"
        description="Kelola batch dan jadwal perawatan ayam"
        action={
          <Button onClick={() => toast.success("Form batch baru siap digunakan")} className="rounded-xl">
            <Plus /> Add Batch
          </Button>
        }
      />
      <Section title="Manajemen Batch">
        <div className={`${card} p-6`}>
          <div className="flex items-center gap-3">
            <h3 className="text-2xl font-bold">Batch #24</h3>
            <span className="rounded bg-success-soft px-2 py-1 text-xs font-bold text-success">Aktif</span>
          </div>
          <div className="mt-6 grid grid-cols-3 gap-5 text-sm">
            <div>
              <span className="text-xs text-muted-foreground">UMUR</span>
              <div className="font-bold">65 Hari</div>
            </div>
            <div>
              <span className="text-xs text-muted-foreground">POPULASI</span>
              <div className="font-bold">1.240 Ayam</div>
            </div>
            <div>
              <span className="text-xs text-muted-foreground">LOKASI</span>
              <div className="flex items-center gap-1 font-bold">
                <MapPin className="size-4" /> Jl. Bendul Merisi Selatan XI No.51, Bendul Merisi, Kec. Wonocolo,
                Surabaya{" "}
              </div>
            </div>
          </div>
        </div>
      </Section>
      <Section title="Jadwal Perawatan">
        <div className="grid gap-4 lg:grid-cols-3">
          {treatmentList.map((t, i) => (
            <Link
              key={t.id}
              to="/treatment/$treatmentId"
              params={{ treatmentId: t.id }}
              className={`${card} flex flex-col p-5 transition-transform hover:-translate-y-0.5`}
            >
              <div className="mb-4 grid size-11 place-items-center rounded-full bg-warning-soft text-warning">
                {i === 2 ? <Wheat /> : <Wrench />}
              </div>
              <h3 className="text-lg font-bold">{t.name}</h3>
              <p className="mt-1 text-sm text-muted-foreground">Target: {t.target}</p>
              <span className="mt-3 w-fit rounded bg-secondary px-2 py-1 text-xs">{t.dueLabel}</span>
              <span className="mt-5 inline-flex h-9 items-center justify-center gap-1 rounded-md border border-border text-sm font-medium">
                <ChevronRight className="size-4" /> Lihat Detail
              </span>
            </Link>
          ))}
        </div>
      </Section>
    </div>
  );
}

export function ProfilePage() {
  const [selected, setSelected] = useState<string | null>(null);
  const rows = [
    [CircleUserRound, "Edit Profil"],
    [LockKeyhole, "Ganti Kata Sandi"],
    [Gauge, "Pengaturan Notifikasi"],
    [Languages, "Bahasa Indonesia"],
    [ShieldCheck, "Kebijakan Privasi"],
  ] as const;
  return (
    <div className="mx-auto max-w-2xl">
      <div className="mb-8 text-center">
        <div className="mx-auto grid size-24 place-items-center rounded-full bg-primary text-3xl font-bold text-primary-foreground">
          AF
        </div>
        <h1 className="mt-4 text-3xl font-bold">Mulyo</h1>
        <span className="mt-2 inline-block rounded-full bg-secondary px-4 py-1 text-sm text-primary">
          Manajer Kandang
        </span>
      </div>
      <div className={`${card} overflow-hidden`}>
        {rows.map(([Icon, label]) => (
          <Button
            variant="ghost"
            onClick={() => setSelected(label)}
            className="grid h-auto w-full grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-4 rounded-none border-b border-border/60 p-5 text-left last:border-0"
            key={label}
          >
            <span className="grid size-10 place-items-center rounded-xl bg-secondary text-primary">
              <Icon />
            </span>
            <span className="font-semibold">{label}</span>
            <ChevronRight className="size-4 text-muted-foreground" />
          </Button>
        ))}
      </div>
      <Button
        onClick={() => toast.info("Sesi tetap aktif pada purwarupa ini")}
        variant="outline"
        className="mt-12 h-12 w-full border-destructive text-destructive"
      >
        <LogOut /> Keluar Akun
      </Button>
      <Dialog open={selected !== null} onOpenChange={(open) => !open && setSelected(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{selected}</DialogTitle>
            <DialogDescription>Pengaturan profil Mulyo</DialogDescription>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            Pilihan ini siap disesuaikan. Perubahan pada purwarupa akan tersimpan selama sesi berlangsung.
          </p>
          <Button
            onClick={() => {
              toast.success(`${selected} diperbarui`);
              setSelected(null);
            }}
          >
            Simpan Perubahan
          </Button>
        </DialogContent>
      </Dialog>
    </div>
  );
}
