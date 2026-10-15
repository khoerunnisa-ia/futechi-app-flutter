import { Link, useRouterState } from "@tanstack/react-router";
import { Bell, Clock3, Home, UtensilsCrossed, Wrench } from "lucide-react";
import type { ReactNode } from "react";
import techi from "@/assets/techi-mascot.png";
import { Button } from "@/components/ui/button";
import { useNotifications } from "@/components/futechi-extra-pages";

const nav = [
  { to: "/", label: "Dashboard", icon: Home },
  { to: "/history", label: "History", icon: Clock3 },
  { to: "/treatment", label: "Treatment", icon: Wrench },
  { to: "/feeding", label: "Feeding", icon: UtensilsCrossed },
] as const;

export function AppShell({ children }: { children: ReactNode }) {
  const path = useRouterState({ select: (state) => state.location.pathname });
  const isChat = path.startsWith("/techi/");
  return <div className="min-h-screen bg-background text-foreground">
    {!isChat && <header className="sticky top-0 z-40 border-b border-border/70 bg-card/95 backdrop-blur">
      <div className="mx-auto flex h-20 max-w-[1100px] items-center justify-between gap-5 px-5 sm:px-6">
        <Link to="/profile" className="flex min-w-0 items-center gap-3 rounded-xl p-1 transition-colors hover:bg-muted">
          <div className="grid size-11 shrink-0 place-items-center rounded-full bg-secondary font-bold text-primary">AF</div>
          <div className="min-w-0"><div className="truncate text-sm font-semibold sm:text-base">Anne Fremant</div><div className="truncate text-xs text-muted-foreground">Manajer Kandang</div></div>
        </Link>
        <NotificationBell/>
      </div>
    </header>}
    <main className={isChat ? "" : "mx-auto max-w-[1100px] px-5 pb-28 pt-7 sm:px-6"}>{children}</main>
    {!isChat && path === "/" && <Link to="/techi/$threadId" params={{threadId:"dashboard"}} aria-label="Buka Techi AI" className="fixed bottom-[92px] right-5 z-40 flex h-14 items-center gap-2 rounded-full bg-primary px-3 pr-5 font-bold text-primary-foreground shadow-xl transition-transform hover:-translate-y-1 sm:right-8"><span className="grid size-10 place-items-center rounded-full bg-card"><img src={techi} alt="" className="size-8 object-contain"/></span>Techi AI</Link>}
    {!isChat && <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-card/97 pb-[env(safe-area-inset-bottom)] shadow-[0_-8px_30px_color-mix(in_oklab,var(--foreground)_8%,transparent)]">
      <div className="mx-auto grid h-[76px] max-w-[680px] grid-cols-4 px-3">{nav.map((item) => { const active = item.to === "/" ? path === "/" : path.startsWith(item.to); const Icon = item.icon; return <Link key={item.to} to={item.to} className={`flex min-w-0 flex-col items-center justify-center gap-1 text-[11px] font-semibold ${active ? "text-primary" : "text-muted-foreground"}`}><span className={`grid size-9 place-items-center rounded-xl ${active ? "bg-primary text-primary-foreground" : ""}`}><Icon className="size-[18px]"/></span><span className="truncate">{item.label}</span></Link> })}</div>
    </nav>}
  </div>;
}
function NotificationBell() {
  const { unread } = useNotifications();
  return <Button asChild aria-label="Notifikasi" variant="ghost" size="icon" className="relative shrink-0 rounded-full"><Link to="/notifications"><Bell className="size-5"/>{unread > 0 && <span className="absolute -right-0.5 -top-0.5 grid min-w-5 place-items-center rounded-full bg-destructive px-1 text-[10px] font-bold text-primary-foreground">{unread}</span>}</Link></Button>;
}
