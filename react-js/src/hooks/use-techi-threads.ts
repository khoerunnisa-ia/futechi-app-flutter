import { useCallback, useEffect, useState } from "react";
import type { UIMessage } from "ai";
import type { HealthCase } from "@/lib/futechi-cases";

const STORAGE_KEY = "futechi-techi-threads-v1";

export type CaseStatus = "pending" | "sick" | "healthy";

export type StoredThread = {
  id: string;
  title: string;
  updatedAt: string;
  messages: UIMessage[];
  checklist: string[];
  selectedSymptoms?: string[];
  caseStatus: CaseStatus;
};

function readThreads(): StoredThread[] {
  if (typeof window === "undefined") return [];
  try {
    const value = JSON.parse(window.localStorage.getItem(STORAGE_KEY) ?? "[]") as unknown;
    return Array.isArray(value) ? (value as StoredThread[]) : [];
  } catch {
    return [];
  }
}

function writeThreads(threads: StoredThread[]) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(threads));
}

function upsertThread(thread: StoredThread) {
  const threads = readThreads();
  const next = [thread, ...threads.filter((item) => item.id !== thread.id)].sort((a, b) =>
    b.updatedAt.localeCompare(a.updatedAt),
  );
  writeThreads(next);
  return next;
}

export function threadTitle(healthCase: HealthCase | undefined) {
  return healthCase
    ? `${healthCase.cage} · ${healthCase.possibilities[0].name}`
    : "Konsultasi operasional";
}

/**
 * Loads, creates, and persists Techi chat threads in localStorage.
 * Returns the stored thread list, the thread for the active threadId (after load),
 * and a persist callback.
 */
export function useTechiThreads(
  threadId: string,
  initial: UIMessage[],
  healthCase: HealthCase | undefined,
) {
  const [threads, setThreads] = useState<StoredThread[]>([]);
  const [loaded, setLoaded] = useState(false);
  const title = threadTitle(healthCase);

  useEffect(() => {
    const stored = readThreads();
    const active = stored.find((item) => item.id === threadId);
    setThreads(stored);
    if (!active) {
      const created: StoredThread = {
        id: threadId,
        title,
        updatedAt: new Date().toISOString(),
        messages: initial,
        checklist: [],
        selectedSymptoms: [],
        caseStatus: "pending",
      };
      setThreads(upsertThread(created));
    }
    setLoaded(true);
  }, [healthCase, initial, threadId, title]);

  const persistThread = useCallback(
    (
      nextMessages: UIMessage[],
      nextChecked: string[],
      nextStatus: CaseStatus,
      nextSymptoms: string[],
    ) => {
      if (typeof window === "undefined") return;
      setThreads(
        upsertThread({
          id: threadId,
          title: threadTitle(healthCase),
          updatedAt: new Date().toISOString(),
          messages: nextMessages,
          checklist: nextChecked,
          selectedSymptoms: nextSymptoms,
          caseStatus: nextStatus,
        }),
      );
    },
    [healthCase, threadId],
  );

  const activeThread = loaded ? threads.find((item) => item.id === threadId) : undefined;

  return { threads, loaded, activeThread, persistThread };
}
