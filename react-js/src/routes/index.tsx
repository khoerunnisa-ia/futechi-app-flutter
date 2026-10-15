import { createFileRoute } from "@tanstack/react-router";
import { DashboardPage } from "@/components/futechi-pages";

// No head() here: the home route inherits title/description/og/twitter from
// __root.tsx, and ships no og:image so serve-time hosting can inject the
// project's social preview (explicit og:image or latest screenshot).
export const Route = createFileRoute("/")({
  head: () => ({ meta: [
    { title: "Dashboard Peternakan — Futechi" },
    { name: "description", content: "Pantau sensor, feeding, CCTV, kesehatan, dan perawatan peternakan Futechi." },
    { property: "og:title", content: "Dashboard Peternakan — Futechi" },
    { property: "og:description", content: "Pusat operasional smart poultry farm Futechi." },
    { property: "og:type", content: "website" },
    { name: "twitter:card", content: "summary_large_image" },
  ]}),
  component: DashboardPage,
});

// IMPORTANT: Replace this placeholder. See ./README.md for routing conventions.
