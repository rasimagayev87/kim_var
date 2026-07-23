import { redirect } from "next/navigation";

import { ReportsFilters } from "@/components/feedback/reports-filters";
import { ReportsTable } from "@/components/feedback/reports-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listReports, type ReportStatusFilter } from "@/lib/data/reports";

function parseStatus(value: string | undefined): ReportStatusFilter {
  return value === "pending" || value === "reviewed" || value === "actioned" || value === "dismissed"
    ? value
    : "all";
}

export default async function FeedbackPage({
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
  const reports = await listReports({ status });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Şikayətlər</h1>
        <p className="text-sm text-muted-foreground">{reports.length} şikayət (son 200 arasından süzülüb)</p>
      </div>

      <ReportsFilters initialStatus={status} />

      <ReportsTable reports={reports} />
    </div>
  );
}
