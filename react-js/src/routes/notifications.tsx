import { createFileRoute } from "@tanstack/react-router";
import { NotificationsPage } from "@/components/futechi-extra-pages";

export const Route = createFileRoute("/notifications")({
  head: () => ({
    meta: [
      { title: "Notifikasi — Futechi" },
      { name: "description", content: "Notifikasi ayam sakit dari analisis video feeding dan pengingat treatment." },
      { property: "og:title", content: "Notifikasi — Futechi" },
      { property: "og:description", content: "Peringatan kesehatan dan pengingat treatment kandang." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: NotificationsPage,
});
