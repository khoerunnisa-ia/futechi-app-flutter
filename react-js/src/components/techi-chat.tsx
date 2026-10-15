import { Link, useNavigate } from "@tanstack/react-router";
import { useChat } from "@ai-sdk/react";
import { DefaultChatTransport, type UIMessage } from "ai";
import {
  ArrowLeft,
  CalendarDays,
  Check,
  CheckSquare,
  ChevronRight,
  MessageSquarePlus,
  PanelLeftClose,
  ShieldCheck,
  Stethoscope,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import techi from "@/assets/techi-mascot.png";
import {
  Conversation,
  ConversationContent,
  ConversationScrollButton,
} from "@/components/ai-elements/conversation";
import { Message, MessageContent, MessageResponse } from "@/components/ai-elements/message";
import {
  PromptInput,
  PromptInputFooter,
  PromptInputSubmit,
  PromptInputTextarea,
} from "@/components/ai-elements/prompt-input";
import { Shimmer } from "@/components/ai-elements/shimmer";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { caseStatusLabel, useCaseState } from "@/lib/futechi-case-state";
import {
  defaultHealthCase,
  getCaseFromThreadId,
  type HealthCase,
  type SuspicionResult,
} from "@/lib/futechi-cases";
import { useTechiThreads, type CaseStatus, type StoredThread } from "@/hooks/use-techi-threads";

const suggested = [
  "Ayam terlihat lesu, apa yang harus diperiksa?",
  "Buat checklist biosekuriti pagi ini",
  "Bagaimana menangani suhu kandang 33°C?",
];

const RESULT_PATTERN = /SUSPECTION_RESULT_START\s*([\s\S]*?)\s*SUSPECTION_RESULT_END/;

function getMessageText(message: UIMessage) {
  return message.parts
    .filter((part) => part.type === "text")
    .map((part) => part.text)
    .join("\n");
}

function parseSuspicionResult(message: UIMessage): SuspicionResult | undefined {
  const match = getMessageText(message).match(RESULT_PATTERN);
  if (!match?.[1]) return undefined;
  try {
    const value = JSON.parse(match[1]) as Partial<SuspicionResult>;
    if (
      typeof value.disease !== "string" ||
      typeof value.confidence !== "number" ||
      typeof value.rationale !== "string" ||
      !Array.isArray(value.mitigation) ||
      typeof value.medication !== "string"
    )
      return undefined;
    return {
      disease: value.disease,
      confidence: value.confidence,
      rationale: value.rationale,
      mitigation: value.mitigation.filter((item): item is string => typeof item === "string"),
      medication: value.medication,
      submittedAt: new Date().toISOString(),
    };
  } catch {
    return undefined;
  }
}

function SuspicionResultCard({ result }: { result: SuspicionResult }) {
  return (
    <div className="mt-3 overflow-hidden rounded-2xl border border-success bg-card shadow-sm">
      <div className="bg-success-soft p-4">
        <div className="flex items-center gap-2 text-xs font-bold uppercase text-success">
          <ShieldCheck className="size-4" /> Hasil Pemeriksaan Techi
        </div>
        <div className="mt-2 text-xl font-bold">{result.disease}</div>
        <div className="mt-1 text-sm font-bold text-success">Kecocokan {result.confidence}%</div>
        <p className="mt-3 text-sm text-foreground">{result.rationale}</p>
      </div>
      <div className="p-4">
        <h3 className="font-bold">Mitigasi yang disarankan</h3>
        <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-muted-foreground">
          {result.mitigation.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
        <div className="mt-4 rounded-xl bg-warning-soft p-3">
          <div className="text-sm font-bold text-warning">Saran obat/penanganan</div>
          <p className="mt-1 text-sm text-muted-foreground">{result.medication}</p>
        </div>
      </div>
    </div>
  );
}

function SuspicionSubmissionCard() {
  return (
    <div className="rounded-2xl border border-primary bg-secondary p-4 text-secondary-foreground">
      <div className="flex items-center gap-2 font-bold">
        <Stethoscope className="size-4" /> Form Suspection dikirim
      </div>
      <p className="mt-1 text-sm">Techi sedang membandingkan gejala yang telah dikonfirmasi.</p>
    </div>
  );
}

function suspicionSymptoms(healthCase: HealthCase) {
  const unique = [...new Set(healthCase.possibilities.flatMap((p) => p.symptoms))];
  const score = (text: string) =>
    [...(healthCase.id + text)].reduce((acc, ch) => (acc * 31 + ch.charCodeAt(0)) % 9973, 7);
  return unique.sort((a, b) => score(a) - score(b));
}

function ChatSidebar({
  healthCase,
  threads,
  threadId,
  onNavigate,
}: {
  healthCase: HealthCase | undefined;
  threads: StoredThread[];
  threadId: string;
  onNavigate: (threadId: string) => void;
}) {
  return (
    <aside className="hidden w-72 shrink-0 border-r border-border bg-warm p-4 md:flex md:flex-col">
      <Link to={healthCase ? "/history" : "/"} className="flex items-center gap-2 font-bold">
        <ArrowLeft className="size-4" /> {healthCase ? "History" : "Dashboard"}
      </Link>
      <Button
        onClick={() => onNavigate(crypto.randomUUID())}
        className="mt-6 justify-start rounded-xl"
      >
        <MessageSquarePlus /> Percakapan baru
      </Button>
      <div className="mt-7 text-xs font-bold uppercase text-muted-foreground">
        Percakapan di perangkat ini
      </div>
      <div className="mt-2 min-h-0 space-y-2 overflow-y-auto">
        {threads.map((item) => (
          <Button
            key={item.id}
            onClick={() => onNavigate(item.id)}
            variant={item.id === threadId ? "secondary" : "ghost"}
            className="h-auto w-full justify-start whitespace-normal rounded-xl p-3 text-left"
          >
            <span className="line-clamp-2">{item.title}</span>
          </Button>
        ))}
      </div>
      <div className="mt-auto rounded-xl bg-success-soft p-3 text-xs text-success">
        <ShieldCheck className="mb-2 size-5" /> Saran AI tidak menggantikan pemeriksaan dokter
        hewan.
      </div>
    </aside>
  );
}

function ChatHeader({
  healthCase,
  sidebar,
  onToggleSidebar,
}: {
  healthCase: HealthCase | undefined;
  sidebar: boolean;
  onToggleSidebar: () => void;
}) {
  return (
    <header className="flex h-20 shrink-0 items-center border-b border-border bg-card px-4 sm:px-6">
      <Button asChild variant="ghost" size="icon">
        {healthCase ? (
          <Link to="/history/consultation/$alertId" params={{ alertId: healthCase.id }}>
            <ArrowLeft />
          </Link>
        ) : (
          <Link to="/">
            <ArrowLeft />
          </Link>
        )}
      </Button>
      <Button
        onClick={onToggleSidebar}
        variant="ghost"
        size="icon"
        className="ml-1 hidden md:inline-flex"
      >
        <PanelLeftClose className={sidebar ? "" : "rotate-180"} />
      </Button>
      <div className="mx-auto font-display text-xl font-bold text-primary">Techi AI</div>
      <img src={techi} alt="Techi AI" width={816} height={816} className="size-11 object-contain" />
    </header>
  );
}

function CaseOverviewCard({
  healthCase,
  status,
  disease,
  confidence,
  onStatus,
}: {
  healthCase: HealthCase;
  status: CaseStatus;
  disease?: string | undefined;
  confidence?: number | undefined;
  onStatus: (next: CaseStatus) => void;
}) {
  return (
    <div className="rounded-[20px] border border-border bg-card p-5 shadow-sm">
      <h1 className="text-xl font-bold sm:text-2xl">
        {healthCase.cage} · {disease ?? "Pemeriksaan Gejala"}
      </h1>
      <div className="mt-3 flex flex-wrap gap-4 text-sm text-muted-foreground">
        <span className="flex items-center gap-1">
          <CalendarDays className="size-4" /> {healthCase.date}
        </span>
        {confidence !== undefined && (
          <span>
            Kecocokan: <b className="text-primary">{confidence}%</b>
          </span>
        )}
      </div>
      <span className="mt-4 inline-flex rounded-full bg-warning-soft px-3 py-1 text-xs font-bold text-warning">
        {caseStatusLabel[status]}
      </span>
      <div className="mt-5 grid grid-cols-2 gap-3 border-t border-border pt-5">
        <Button
          onClick={() => onStatus("sick")}
          variant={status === "sick" ? "destructive" : "outline"}
        >
          {status === "sick" && <Check />} Konfirmasi Sakit
        </Button>
        <Button
          onClick={() => onStatus("healthy")}
          variant={status === "healthy" ? "default" : "outline"}
        >
          {status === "healthy" && <Check />} Tandai Sehat
        </Button>
      </div>
    </div>
  );
}

function SuspectionForm({
  healthCase,
  selectedSymptoms,
  onToggle,
  onSubmit,
  disabled,
}: {
  healthCase: HealthCase;
  selectedSymptoms: string[];
  onToggle: (symptom: string) => void;
  onSubmit: () => void;
  disabled: boolean;
}) {
  return (
    <section className="mt-6 rounded-[20px] border border-border bg-card p-5 shadow-sm">
      <div className="flex items-center gap-2">
        <Stethoscope className="text-primary" />
        <h2 className="text-xl font-bold">Form Suspection</h2>
      </div>
      <p className="mt-2 text-sm text-muted-foreground">
        Periksa ayam secara langsung. Centang setiap gejala yang benar-benar terlihat dan biarkan
        kosong bila tidak ditemukan.
      </p>
      <div className="mt-5 grid gap-2 rounded-xl border border-border p-4 sm:grid-cols-2">
        {suspicionSymptoms(healthCase).map((symptom) => (
          <label
            key={symptom}
            className="flex cursor-pointer items-center gap-3 rounded-lg bg-muted/50 p-3 text-sm"
          >
            <Checkbox
              checked={selectedSymptoms.includes(symptom)}
              onCheckedChange={() => onToggle(symptom)}
              aria-label={symptom}
              className="size-5 rounded-[4px]"
            />
            <span>{symptom}</span>
          </label>
        ))}
      </div>
      <Button onClick={onSubmit} disabled={disabled} className="mt-5 w-full">
        <CheckSquare /> Kirim Hasil Pemeriksaan
      </Button>
      {selectedSymptoms.length === 0 && (
        <p className="mt-2 text-center text-xs text-muted-foreground">
          Centang setidaknya satu gejala untuk mengirim pemeriksaan.
        </p>
      )}
    </section>
  );
}

function SuggestedPrompts({ onSelect }: { onSelect: (text: string) => void }) {
  return (
    <div className="mt-5 grid gap-2">
      {suggested.map((item) => (
        <Button
          variant="outline"
          key={item}
          onClick={() => onSelect(item)}
          className="h-auto justify-between whitespace-normal rounded-xl p-3 text-left"
        >
          {item}
          <ChevronRight className="size-4 shrink-0" />
        </Button>
      ))}
    </div>
  );
}

function makeWelcome(threadId: string): UIMessage {
  const healthCase = getCaseFromThreadId(threadId);
  const text = healthCase
    ? `Hai Anne. Berdasarkan analisis visual, ayam di **${healthCase.cage}** menunjukkan perubahan perilaku yang perlu dikonfirmasi. Silakan periksa ayam secara langsung dan isi Form Suspection di bawah dengan mencentang gejala yang benar-benar terlihat. Selesaikan juga checklist observasi dan beri tahu saya bila ada perubahan kondisi.`
    : "Halo Anne! Saya **Techi**. Saya dapat membantu mengevaluasi gejala, menyiapkan langkah operasional, dan membaca kondisi kandang. Apa yang ingin Anda periksa hari ini?";
  return { id: `welcome-${threadId}`, role: "assistant", parts: [{ type: "text", text }] };
}

export function TechiHome() {
  return <TechiChat threadId="current" />;
}

export function TechiChat({ threadId }: { threadId: string }) {
  const healthCase = getCaseFromThreadId(threadId);
  const caseState = useCaseState(healthCase ?? defaultHealthCase);
  const initial = useMemo<UIMessage[]>(() => [makeWelcome(threadId)], [threadId]);
  const transport = useMemo(
    () =>
      new DefaultChatTransport({
        api: "/api/chat",
        prepareSendMessagesRequest: ({ messages }) => ({
          body: { messages, threadId, caseId: healthCase?.id },
        }),
      }),
    [threadId, healthCase?.id],
  );
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const navigate = useNavigate();
  const [sidebar, setSidebar] = useState(true);
  const [checked, setChecked] = useState<string[]>([]);
  const [selectedSymptoms, setSelectedSymptoms] = useState<string[]>([]);
  const [caseStatus, setCaseStatus] = useState<CaseStatus>("pending");
  const restoredRef = useRef(false);

  const { threads, loaded, activeThread, persistThread } = useTechiThreads(
    threadId,
    initial,
    healthCase,
  );

  const persist = useCallback(
    (
      nextMessages: UIMessage[],
      nextChecked = checked,
      nextStatus = caseStatus,
      nextSymptoms = selectedSymptoms,
    ) => {
      persistThread(nextMessages, nextChecked, nextStatus, nextSymptoms);
    },
    [caseStatus, checked, persistThread, selectedSymptoms],
  );

  const { messages, setMessages, sendMessage, status, stop, error } = useChat({
    id: threadId,
    messages: initial,
    transport,
    onFinish: ({ messages: completed }) => {
      persist(completed);
      const last = completed.at(-1);
      if (last && healthCase) {
        const result = parseSuspicionResult(last);
        if (result) caseState.setSuspicionResult(result);
      }
    },
  });

  // Restore stored thread state once when the thread first loads.
  useEffect(() => {
    if (!loaded) return;
    if (activeThread && !restoredRef.current) {
      restoredRef.current = true;
      setMessages(activeThread.messages.length ? activeThread.messages : initial);
      setChecked(activeThread.checklist ?? []);
      setSelectedSymptoms(activeThread.selectedSymptoms ?? []);
      setCaseStatus(activeThread.caseStatus ?? "pending");
    } else if (!activeThread) {
      restoredRef.current = false;
    }
  }, [activeThread, initial, loaded, setMessages]);

  useEffect(() => {
    if (healthCase) setCaseStatus(caseState.status);
  }, [caseState.status, healthCase]);

  useEffect(() => {
    if (loaded) inputRef.current?.focus();
  }, [loaded, status, threadId]);

  const updateCaseStatus = (next: CaseStatus) => {
    setCaseStatus(next);
    if (healthCase) caseState.setStatus(next);
    persist(messages, checked, next);
  };
  const toggleSymptom = (id: string) => {
    const next = selectedSymptoms.includes(id)
      ? selectedSymptoms.filter((item) => item !== id)
      : [...selectedSymptoms, id];
    setSelectedSymptoms(next);
    persist(messages, checked, caseStatus, next);
  };
  const submitSuspicion = () => {
    if (
      !healthCase ||
      selectedSymptoms.length === 0 ||
      status === "submitted" ||
      status === "streaming"
    )
      return;
    const observations = healthCase.possibilities.map((possibility) => ({
      disease: possibility.name,
      baselineConfidence: possibility.confidence,
      symptoms: possibility.symptoms.map((symptom) => ({
        symptom,
        observed: selectedSymptoms.includes(symptom),
      })),
    }));
    void sendMessage({
      text: `[FORM SUSPECTION]\nPeternak telah menyelesaikan pemeriksaan gejala untuk ${healthCase.chickenId}. Analisis data berikut dan berikan hasil pemeriksaan terstruktur.\n${JSON.stringify(observations)}`,
    });
  };
  const submit = (text: string) => {
    const clean = text.trim();
    if (clean && status !== "submitted" && status !== "streaming")
      void sendMessage({ text: clean });
  };
  return (
    <div className="flex h-dvh overflow-hidden bg-background">
      {sidebar && (
        <ChatSidebar
          healthCase={healthCase}
          threads={threads}
          threadId={threadId}
          onNavigate={(next) =>
            navigate({ to: "/techi/$threadId", params: { threadId: next } })
          }
        />
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <ChatHeader
          healthCase={healthCase}
          sidebar={sidebar}
          onToggleSidebar={() => setSidebar((value) => !value)}
        />
        <Conversation className="min-h-0 flex-1">
          <ConversationContent className="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6">
            {healthCase && (
              <CaseOverviewCard
                healthCase={healthCase}
                status={caseStatus}
                disease={caseState.suspicionResult?.disease}
                confidence={caseState.suspicionResult?.confidence}
                onStatus={updateCaseStatus}
              />
            )}
            {messages.map((message) => {
              const result = parseSuspicionResult(message);
              const isSuspicionSubmission = getMessageText(message).startsWith("[FORM SUSPECTION]");
              return (
                <Message from={message.role} key={message.id} className="mt-5">
                  <MessageContent>
                    {isSuspicionSubmission ? <SuspicionSubmissionCard /> : null}
                    {message.parts.map((part, index) =>
                      part.type === "text" &&
                      !isSuspicionSubmission &&
                      !RESULT_PATTERN.test(part.text) ? (
                        <MessageResponse key={index}>{part.text}</MessageResponse>
                      ) : null,
                    )}
                    {result ? <SuspicionResultCard result={result} /> : null}
                  </MessageContent>
                </Message>
              );
            })}
            {status === "submitted" && (
              <div className="mt-4 flex items-center gap-2 text-sm text-muted-foreground">
                <img src={techi} alt="" className="size-7 object-contain" />
                <Shimmer>Techi sedang memeriksa kondisi...</Shimmer>
              </div>
            )}
            {error && (
              <div className="mt-4 rounded-xl bg-danger-soft p-3 text-sm text-destructive">
                {error.message}
              </div>
            )}
            {healthCase && !caseState.suspicionResult && (
              <SuspectionForm
                healthCase={healthCase}
                selectedSymptoms={selectedSymptoms}
                onToggle={toggleSymptom}
                onSubmit={submitSuspicion}
                disabled={
                  selectedSymptoms.length === 0 ||
                  status === "submitted" ||
                  status === "streaming"
                }
              />
            )}
            {!healthCase && messages.length === 1 && <SuggestedPrompts onSelect={submit} />}
          </ConversationContent>
          <ConversationScrollButton />
        </Conversation>
        <div className="border-t border-border bg-card p-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
          <div className="mx-auto max-w-3xl">
            <PromptInput onSubmit={(message) => submit(message.text)} className="rounded-2xl">
              <PromptInputTextarea ref={inputRef} placeholder="Ketik pesan untuk Techi..." />
              <PromptInputFooter>
                <span className="px-1 text-xs text-muted-foreground">
                  Techi AI dapat membuat kesalahan
                </span>
                <PromptInputSubmit status={status} onStop={stop} />
              </PromptInputFooter>
            </PromptInput>
          </div>
        </div>
      </div>
    </div>
  );
}
