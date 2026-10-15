import { Outlet, createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/techi")({
  component: TechiLayout,
});

function TechiLayout() {
  return <Outlet />;
}