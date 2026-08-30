import { redirect } from "next/navigation";

import { PinBoxesFilters } from "@/components/pinboxes/pinboxes-filters";
import { PinBoxesTable } from "@/components/pinboxes/pinboxes-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listPinBoxes, type PinBoxStatusFilter } from "@/lib/data/pinboxes";

function parseStatus(value: string | undefined): PinBoxStatusFilter {
  return value === "pending" || value === "active" || value === "soldOut" || value === "expired" || value === "rejected"
    ? value
    : "all";
}

export default async function PinBoxesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewPinBoxes")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const search = params.q ?? "";
  const status = parseStatus(params.status);

  const pinboxes = await listPinBoxes({ status, search });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">PinBox</h1>
        <p className="text-sm text-muted-foreground">{pinboxes.length} qutu (son 200 arasından süzülüb)</p>
      </div>

      <PinBoxesFilters initialSearch={search} initialStatus={status} />

      <PinBoxesTable pinboxes={pinboxes} />
    </div>
  );
}
