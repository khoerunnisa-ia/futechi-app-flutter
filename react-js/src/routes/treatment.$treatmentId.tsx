import { createFileRoute } from "@tanstack/react-router";
import { TreatmentDetailPage } from "@/components/futechi-extra-pages";
import { getTreatment } from "@/lib/futechi-treatments";

export const Route = createFileRoute("/treatment/$treatmentId")({
  head: ({ params }) => {
    const t = getTreatment(params.treatmentId);
    const title = `${t?.name ?? "Detail Treatment"} — Futechi`;
    return {
      meta: [
        { title },
        { name: "description", content: "Detail obat, dosis, panduan pemberian, dan reminder treatment." },
        { property: "og:title", content: title },
        { property: "og:description", content: "Panduan treatment ayam langkah demi langkah." },
        { property: "og:type", content: "article" },
        { name: "twitter:card", content: "summary" },
      ],
    };
  },
  component: TreatmentDetailRoute,
});

function TreatmentDetailRoute() {
  const { treatmentId } = Route.useParams();
  return <TreatmentDetailPage treatment={getTreatment(treatmentId)} />;
}
