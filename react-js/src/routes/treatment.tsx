import { Outlet, createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/treatment")({
  component: TreatmentLayout,
});

function TreatmentLayout() {
  return <Outlet />;
}
