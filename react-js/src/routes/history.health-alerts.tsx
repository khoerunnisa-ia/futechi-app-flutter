import { createFileRoute } from "@tanstack/react-router";
import { HealthAlertsPage } from "@/components/futechi-pages";

export const Route = createFileRoute("/history/health-alerts")({
  head: () => ({
    meta: [
      { title: "Kasus Kesehatan Aktif — Futechi" },
      {
        name: "description",
        content: "Daftar ayam sakit dan menunggu konfirmasi di peternakan Futechi.",
      },
      { property: "og:title", content: "Kasus Kesehatan Aktif — Futechi" },
      {
        property: "og:description",
        content: "Tinjau kasus kesehatan ayam yang masih memerlukan perhatian.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: HealthAlertsPage,
});
