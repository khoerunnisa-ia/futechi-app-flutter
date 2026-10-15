import { Link } from "@tanstack/react-router";
import {
  ArrowLeft,
  BellRing,
  CheckCheck,
  ExternalLink,
  PlayCircle,
  Pill,
  ShoppingCart,
  Syringe,
  Video,
  Wrench,
} from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import sickChicken from "@/assets/sick-chicken-feeding.jpg";
import feedingMorningAsset from "@/assets/chickens-feeding-morning.jpg.asset.json";
import feedingEveningAsset from "@/assets/chickens-feeding-evening.jpg.asset.json";
import avianAsset from "@/assets/avian-influenza.jpg.asset.json";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { useCaseStatuses } from "@/lib/futechi-case-state";
import { sortedHealthCases } from "@/lib/futechi-cases";
import {
  treatments,
  useReadNotifications,
  useReminders,
  type Treatment,
} from "@/lib/futechi-treatments";

const card = "rounded-[20px] border border-border/70 bg-card shadow-sm";
const images = {
  sick: sickChicken,
  morning: feedingMorningAsset.url,
  evening: feedingEveningAsset.url,
  avian: avianAsset.url,
};

type Notif = {
  id: string;
  kind: "health" | "treatment";
  title: string;
  body: string;
  time: string;
  urgent: boolean;
  image?: string;
  link:
    | { to: "/history/consultation/$alertId"; id: string }
    | { to: "/treatment/$treatmentId"; id: string };
};

export function useNotifications() {
  const statuses = useCaseStatuses(sortedHealthCases);
  const [reminders] = useReminders();
  const [read, setRead] = useReadNotifications();
  const list: Notif[] = [
    ...sortedHealthCases
      .filter((c) => statuses[c.id] !== "healthy")
      .map((c) => ({
        id: `case-${c.id}`,
        kind: "health" as const,
        title: `Ayam terdeteksi sakit · ${c.cage}`,
        body: `Hasil analisis video feeding ${c.session === "morning" ? "Pagi" : "Sore"} pada ${c.chickenId}. Segera lakukan pemeriksaan gejala.`,
        time: `${c.date}, ${c.time}`,
        urgent: c.level === "Kritis",
        image: images[c.image],
        link: { to: "/history/consultation/$alertId" as const, id: c.id },
      })),
    ...treatments
      .filter((t) => reminders[t.id]?.enabled !== false)
      .map((t) => {
        const snoozed = reminders[t.id]?.snoozedUntil;
        return {
          id: `treat-${t.id}${snoozed ? `-${snoozed}` : ""}`,
          kind: "treatment" as const,
          title: `Pengingat: ${t.name}`,
          body: snoozed
            ? `Reminder ditunda hingga ${new Date(snoozed).toLocaleString("id-ID", { dateStyle: "medium", timeStyle: "short" })}.`
            : `${t.target} · ${t.product}`,
          time: t.schedule,
          urgent: t.status === "Mendesak",
          link: { to: "/treatment/$treatmentId" as const, id: t.id },
        };
      }),
  ];
  const unread = list.filter((n) => !read.includes(n.id)).length;
  const markRead = (ids: string[]) => setRead([...new Set([...read, ...ids])]);
  return { list, read, unread, markRead };
}

export function NotificationsPage() {
  const { list, read, unread, markRead } = useNotifications();
  const [tab, setTab] = useState<"all" | "health" | "treatment">("all");
  const shown = list.filter((n) => tab === "all" || n.kind === tab);
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Notifikasi</h1>
          <p className="text-muted-foreground">{unread} notifikasi belum dibaca</p>
        </div>
        <Button variant="outline" onClick={() => markRead(list.map((n) => n.id))}>
          <CheckCheck /> Tandai semua dibaca
        </Button>
      </div>
      <div className="flex gap-2">
        {(
          [
            ["all", "Semua"],
            ["health", "Kesehatan"],
            ["treatment", "Treatment"],
          ] as const
        ).map(([key, label]) => (
          <Button
            key={key}
            size="sm"
            variant={tab === key ? "default" : "outline"}
            className="rounded-full"
            onClick={() => setTab(key)}
          >
            {label}
          </Button>
        ))}
      </div>
      <div className="grid gap-3">
        {shown.length === 0 && (
          <div className={`${card} p-8 text-center text-muted-foreground`}>
            Tidak ada notifikasi.
          </div>
        )}
        {shown.map((n) => {
          const isRead = read.includes(n.id);
          const inner = (
            <>
              {n.image ? (
                <img src={n.image} alt="" className="size-14 rounded-xl object-cover" />
              ) : (
                <span className="grid size-14 place-items-center rounded-xl bg-warning-soft text-warning">
                  <BellRing />
                </span>
              )}
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-bold">{n.title}</span>
                  {n.urgent && (
                    <span className="rounded bg-danger-soft px-2 py-0.5 text-[11px] font-bold text-destructive">
                      {n.kind === "health" ? "Kritis" : "Mendesak"}
                    </span>
                  )}
                </div>
                <p className="mt-1 text-sm text-muted-foreground">{n.body}</p>
                <p className="mt-1 flex items-center gap-1 text-xs text-muted-foreground">
                  {n.kind === "health" ? (
                    <Video className="size-3" />
                  ) : (
                    <Wrench className="size-3" />
                  )}
                  {n.time}
                </p>
              </div>
              {!isRead && (
                <span className="size-2.5 rounded-full bg-destructive" aria-label="Belum dibaca" />
              )}
            </>
          );
          const cls = `${card} grid grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-4 p-4 transition-colors hover:bg-muted/40 ${isRead ? "opacity-75" : ""}`;
          return n.link.to === "/history/consultation/$alertId" ? (
            <Link
              key={n.id}
              to={n.link.to}
              params={{ alertId: n.link.id }}
              onClick={() => markRead([n.id])}
              className={cls}
            >
              {inner}
            </Link>
          ) : (
            <Link
              key={n.id}
              to={n.link.to}
              params={{ treatmentId: n.link.id }}
              onClick={() => markRead([n.id])}
              className={cls}
            >
              {inner}
            </Link>
          );
        })}
      </div>
    </div>
  );
}

export function TreatmentDetailPage({ treatment }: { treatment: Treatment | undefined }) {
  const [reminders, setReminders] = useReminders();
  if (!treatment)
    return (
      <div className={`${card} p-8 text-center`}>
        <p className="font-bold">Treatment tidak ditemukan.</p>
        <Button asChild className="mt-4">
          <Link to="/treatment">Kembali ke Treatment</Link>
        </Button>
      </div>
    );
  const reminder = reminders[treatment.id] ?? { enabled: true };
  const update = (next: typeof reminder) => setReminders({ ...reminders, [treatment.id]: next });
  const snooze = (hours: number, label: string) => {
    update({ enabled: true, snoozedUntil: new Date(Date.now() + hours * 3600_000).toISOString() });
    toast.success(`Reminder ditunda ${label}`);
  };
  const next = reminder.snoozedUntil
    ? new Date(reminder.snoozedUntil).toLocaleString("id-ID", {
        dateStyle: "medium",
        timeStyle: "short",
      })
    : treatment.schedule;
  return (
    <div className="space-y-6">
      <Link
        to="/treatment"
        className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" /> Kembali ke Treatment
      </Link>
      <div className={`${card} p-6`}>
        <span
          className={`rounded px-2 py-1 text-xs font-bold ${treatment.status === "Mendesak" ? "bg-danger-soft text-destructive" : "bg-secondary text-primary"}`}
        >
          {treatment.status}
        </span>
        <h1 className="mt-3 text-3xl font-bold">{treatment.name}</h1>
        <p className="mt-1 text-muted-foreground">
          {treatment.schedule} · {treatment.target}
        </p>
      </div>
      <div className="grid gap-6 lg:grid-cols-2">
        <section className={`${card} p-6`}>
          <h2 className="flex items-center gap-2 text-xl font-bold">
            <Pill className="text-primary" /> Informasi Obat
          </h2>
          <dl className="mt-4 grid gap-3 text-sm">
            <div>
              <dt className="text-xs text-muted-foreground">PRODUK</dt>
              <dd className="font-semibold">{treatment.product}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">KANDUNGAN</dt>
              <dd className="font-semibold">{treatment.ingredient}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">BENTUK SEDIAAN</dt>
              <dd className="font-semibold">{treatment.form}</dd>
            </div>
          </dl>
        </section>
        <section className={`${card} p-6`}>
          <h2 className="flex items-center gap-2 text-xl font-bold">
            <Syringe className="text-primary" /> Dosis
          </h2>
          <p className="mt-4 text-sm font-semibold">{treatment.dosage}</p>
          <p className="mt-3 rounded-xl bg-warning-soft p-3 text-sm text-warning">
            {treatment.safety}
          </p>
        </section>
      </div>
      <section className={`${card} p-6`}>
        <h2 className="text-xl font-bold">Panduan Pemberian</h2>
        <ol className="mt-4 grid gap-3">
          {treatment.steps.map((step, i) => (
            <li key={step} className="flex gap-3 rounded-xl bg-muted/50 p-3 text-sm">
              <span className="grid size-7 shrink-0 place-items-center rounded-full bg-primary text-xs font-bold text-primary-foreground">
                {i + 1}
              </span>
              <span className="pt-1">{step}</span>
            </li>
          ))}
        </ol>
        <div className="mt-5 grid gap-3 sm:grid-cols-2">
          <Button asChild className="h-11">
            <a href={treatment.buyUrl} target="_blank" rel="noreferrer">
              <ShoppingCart /> Beli Produk <ExternalLink className="size-3" />
            </a>
          </Button>
          <Button asChild variant="outline" className="h-11">
            <a href={treatment.tutorialUrl} target="_blank" rel="noreferrer">
              <PlayCircle /> Tonton Tutorial <ExternalLink className="size-3" />
            </a>
          </Button>
        </div>
      </section>
      <section className={`${card} p-6`}>
        <div className="flex items-center justify-between gap-4">
          <div>
            <h2 className="flex items-center gap-2 text-xl font-bold">
              <BellRing className="text-primary" /> Reminder
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {reminder.enabled ? `Pengingat berikutnya: ${next}` : "Reminder dinonaktifkan"}
            </p>
          </div>
          <Switch
            aria-label="Aktifkan reminder"
            checked={reminder.enabled}
            onCheckedChange={(enabled) => {
              update({ enabled });
              toast.success(enabled ? "Reminder diaktifkan" : "Reminder dinonaktifkan");
            }}
          />
        </div>
        {reminder.enabled && (
          <div className="mt-4 flex flex-wrap gap-2">
            <span className="self-center text-sm text-muted-foreground">Tunda:</span>
            <Button size="sm" variant="outline" onClick={() => snooze(1, "1 jam")}>
              1 jam
            </Button>
            <Button size="sm" variant="outline" onClick={() => snooze(3, "3 jam")}>
              3 jam
            </Button>
            <Button size="sm" variant="outline" onClick={() => snooze(24, "hingga besok")}>
              Besok
            </Button>
          </div>
        )}
      </section>
      <p className="text-center text-xs text-muted-foreground">
        Data obat, dosis, dan link merupakan contoh. Selalu ikuti label produk dan arahan dokter
        hewan.
      </p>
    </div>
  );
}
