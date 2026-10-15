import { createFileRoute } from "@tanstack/react-router";
import { ConsultationPage } from "@/components/futechi-pages";

export const Route = createFileRoute("/history/consultation/$alertId")({
  head: () => ({ meta: [
    { title: "Konsultasi Peringatan Kesehatan — Futechi" },
    { name: "description", content: "Tinjau indikasi kesehatan ayam dan panduan penanganan Techi AI." },
    { property: "og:title", content: "Konsultasi Peringatan Kesehatan — Futechi" },
    { property: "og:description", content: "Konfirmasi kondisi ayam dan ikuti panduan penanganan." },
    { property: "og:type", content: "website" },
    { name: "twitter:card", content: "summary_large_image" },
  ]}),
  component: ConsultationRoute,
});

function ConsultationRoute() {
  const { alertId } = Route.useParams();
  return <ConsultationPage alertId={alertId} />;
}