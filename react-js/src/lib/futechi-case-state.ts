import { useCallback, useEffect, useState } from "react";
import type { CaseStatus, HealthCase, SuspicionResult } from "@/lib/futechi-cases";

const STORAGE_KEY = "futechi-case-state-v2";
const CHANGE_EVENT = "futechi-case-state-change";

type StoredCaseState = Record<string, { status?: CaseStatus; suspicionResult?: SuspicionResult }>;

function readAll(): StoredCaseState {
  if (typeof window === "undefined") return {};
  try {
    const parsed = JSON.parse(window.localStorage.getItem(STORAGE_KEY) ?? "{}") as unknown;
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? (parsed as StoredCaseState)
      : {};
  } catch {
    return {};
  }
}

function updateCase(caseId: string, patch: StoredCaseState[string]) {
  const current = readAll();
  window.localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      ...current,
      [caseId]: { ...current[caseId], ...patch },
    }),
  );
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT));
}

export function getStoredCaseStatus(item: HealthCase) {
  return readAll()[item.id]?.status ?? item.initialStatus;
}

export function getStoredSuspicionResult(caseId: string) {
  return readAll()[caseId]?.suspicionResult;
}

export function useCaseState(item: HealthCase) {
  const [status, setStatusState] = useState<CaseStatus>(item.initialStatus);
  const [suspicionResult, setSuspicionResultState] = useState<SuspicionResult | undefined>();

  const refresh = useCallback(() => {
    const stored = readAll()[item.id];
    setStatusState(stored?.status ?? item.initialStatus);
    setSuspicionResultState(stored?.suspicionResult);
  }, [item.id, item.initialStatus]);

  useEffect(() => {
    refresh();
    window.addEventListener("storage", refresh);
    window.addEventListener(CHANGE_EVENT, refresh);
    return () => {
      window.removeEventListener("storage", refresh);
      window.removeEventListener(CHANGE_EVENT, refresh);
    };
  }, [refresh]);

  const setStatus = useCallback(
    (next: CaseStatus) => updateCase(item.id, { status: next }),
    [item.id],
  );
  const setSuspicionResult = useCallback(
    (next: SuspicionResult) => updateCase(item.id, { suspicionResult: next }),
    [item.id],
  );

  return { status, setStatus, suspicionResult, setSuspicionResult };
}

export const caseStatusLabel: Record<CaseStatus, string> = {
  pending: "Menunggu Konfirmasi",
  sick: "Sakit",
  healthy: "Sudah Sehat",
};

export function useCaseStatuses(items: HealthCase[]) {
  const [statuses, setStatuses] = useState<Record<string, CaseStatus>>(() =>
    Object.fromEntries(items.map((item) => [item.id, item.initialStatus])),
  );

  const refresh = useCallback(() => {
    setStatuses(Object.fromEntries(items.map((item) => [item.id, getStoredCaseStatus(item)])));
  }, [items]);

  useEffect(() => {
    refresh();
    window.addEventListener("storage", refresh);
    window.addEventListener(CHANGE_EVENT, refresh);
    return () => {
      window.removeEventListener("storage", refresh);
      window.removeEventListener(CHANGE_EVENT, refresh);
    };
  }, [refresh]);

  return statuses;
}
