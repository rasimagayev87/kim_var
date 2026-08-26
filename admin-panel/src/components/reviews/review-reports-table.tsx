import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminReviewReportRow } from "@/lib/data/review-reports";
import { ReviewReportActions } from "./review-report-actions";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function ReviewReportsTable({ reports }: { reports: AdminReviewReportRow[] }) {
  if (reports.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrə uyğun rəy şikayəti tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Rəy</TableHead>
            <TableHead>Məkan</TableHead>
            <TableHead>Şikayət edən</TableHead>
            <TableHead>Səbəb</TableHead>
            <TableHead>Tarix</TableHead>
            <TableHead>Status</TableHead>
            <TableHead>Əməliyyat</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {reports.map((report) => (
            <TableRow key={report.id}>
              <TableCell className="max-w-[240px] text-sm font-medium">
                {report.reviewDeleted ? (
                  <span className="text-muted-foreground italic">Rəy artıq silinib</span>
                ) : (
                  <>
                    <span className="text-muted-foreground">{report.reviewRating ?? "—"}★ — </span>
                    <span className="line-clamp-2">{report.reviewComment}</span>
                  </>
                )}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{report.venueName || "—"}</TableCell>
              <TableCell className="text-sm">{report.reporterName}</TableCell>
              <TableCell className="max-w-[220px] truncate text-sm text-muted-foreground">{report.reason}</TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(report.createdAt)}</TableCell>
              <TableCell>
                <StatusBadge status={report.status} />
              </TableCell>
              <TableCell>
                <ReviewReportActions reportId={report.id} reviewId={report.reviewId} status={report.status} reviewDeleted={report.reviewDeleted} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
