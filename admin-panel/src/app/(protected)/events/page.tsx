import { redirect } from "next/navigation";

import { EventsFilters } from "@/components/events/events-filters";
import { EventsTable } from "@/components/events/events-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listEvents, parseEventStatusFilter } from "@/lib/data/events";

/**
 * The events queue.
 *
 * `viewEvents`, not a new permission and not `manageFeedback`: the
 * access decision for this screen was already made and reviewed in
 * PERMISSION_MATRIX long before the screen existed, which is exactly
 * what that matrix's doc comment asks whoever builds it to honour.
 * Actions are gated separately on `moderateEvents`.
 */
export default async function EventsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; venueId?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewEvents")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const search = params.q ?? "";
  const status = parseEventStatusFilter(params.status);
  const events = await listEvents({ status, search, venueId: params.venueId });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Tədbirlər</h1>
        <p className="text-sm text-muted-foreground">
          {events.length} tədbir (son 200 arasından süzülüb). Yeni məkanın ilk 3 tədbiri baxışa düşür; tədbir öz
          başlama vaxtını keçsə avtomatik rədd edilir.
        </p>
      </div>

      <EventsFilters initialSearch={search} initialStatus={status} />

      <EventsTable events={events} />
    </div>
  );
}
