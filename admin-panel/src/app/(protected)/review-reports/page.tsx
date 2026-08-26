import { redirect } from "next/navigation";

import { ReviewReportsFilters } from "@/components/reviews/review-reports-filters";
import { ReviewReportsTable } from "@/components/reviews/review-reports-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listReviewReports, type ReviewReportStatusFilter } from "@/lib/data/review-reports";

function parseStatus(value: string | undefined): ReviewReportStatusFilter {
  return value === "pending" || value === "resolved" || value === "dismissed" ? value : "all";
}

export default async function ReviewReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const status = parseStatus(params.status);
  const reports = await listReviewReports({ status });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Rəy şikayətləri</h1>
        <p className="text-sm text-muted-foreground">{reports.length} şikayət (son 200 arasından süzülüb)</p>
      </div>

      <ReviewReportsFilters initialStatus={status} />

      <ReviewReportsTable reports={reports} />
    </div>
  );
}
