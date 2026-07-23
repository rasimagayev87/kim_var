import { redirect } from "next/navigation";

import { VenuesFilters } from "@/components/venues/venues-filters";
import { VenuesTable } from "@/components/venues/venues-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listVenues, type VenueStatusFilter } from "@/lib/data/venues";

function parseStatus(value: string | undefined): VenueStatusFilter {
  return value === "pending" || value === "active" || value === "inactive" || value === "rejected" ? value : "all";
}

export default async function VenuesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const search = params.q ?? "";
  const status = parseStatus(params.status);

  const venues = await listVenues({ status, search });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Məkanlar</h1>
        <p className="text-sm text-muted-foreground">{venues.length} məkan (son 200 arasından süzülüb)</p>
      </div>

      <VenuesFilters initialSearch={search} initialStatus={status} />

      <VenuesTable venues={venues} />
    </div>
  );
}
