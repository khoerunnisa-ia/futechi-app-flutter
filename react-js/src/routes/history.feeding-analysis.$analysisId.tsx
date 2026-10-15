import { createFileRoute } from "@tanstack/react-router";
import { FeedingAnalysisPage } from "@/components/futechi-pages";

export const Route = createFileRoute("/history/feeding-analysis/$analysisId")({
  head: () => ({ meta: [
    { title: "Detail Analisis Feeding — Futechi" },
    { name: "description", content: "Detail analisis kamera setelah sesi pemberian pakan." },
    { property: "og:title", content: "Detail Analisis Feeding — Futechi" },
    { property: "og:description", content: "Tinjau hasil pemantauan ayam setelah sesi feeding." },
    { property: "og:type", content: "website" },
    { name: "twitter:card", content: "summary_large_image" },
  ]}),
  component: FeedingAnalysisRoute,
});

function FeedingAnalysisRoute() {
  const { analysisId } = Route.useParams();
  return <FeedingAnalysisPage analysisId={analysisId} />;
}