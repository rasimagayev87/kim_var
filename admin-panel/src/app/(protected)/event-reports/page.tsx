import { redirect } from "next/navigation";

import { EventReportsFilters } from "@/components/events/event-reports-filters";
import { EventReportsTable } from "@/components/events/event-reports-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listEventReports, type EventReportStatusFilter } from "@/lib/data/event-reports";

function parseStatus(value: string | undefined): EventReportStatusFilter {
  return value === "open" || value === "resolved" || value === "dismissed" ? value : "all";
}

export default async function EventReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageFeedback")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const status = parseStatus(params.status);
  const reports = await listEventReports({ status });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Tədbir şikayətləri</h1>
        <p className="text-sm text-muted-foreground">{reports.length} şikayət (son 200 arasından süzülüb)</p>
      </div>

      <EventReportsFilters initialStatus={status} />

      <EventReportsTable reports={reports} />
    </div>
  );
}
