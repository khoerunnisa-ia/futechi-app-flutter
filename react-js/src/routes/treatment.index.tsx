import { createFileRoute } from "@tanstack/react-router";
import { TreatmentPage } from "@/components/futechi-pages";

export const Route = createFileRoute("/treatment/")({
  head: () => ({
    meta: [
      { title: "Treatment & Batch — Futechi" },
      { name: "description", content: "Kelola batch dan jadwal perawatan ayam." },
      { property: "og:title", content: "Treatment & Batch — Futechi" },
      { property: "og:description", content: "Perawatan peternakan yang terjadwal." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: TreatmentPage,
});
