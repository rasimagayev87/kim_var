import Link from "next/link";

import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminReportRow } from "@/lib/data/reports";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function ReportsTable({ reports }: { reports: AdminReportRow[] }) {
  if (reports.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrə uyğun şikayət tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Şikayət edən</TableHead>
            <TableHead>Şikayət olunan</TableHead>
            <TableHead>Səbəb</TableHead>
            <TableHead>Tarix</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {reports.map((report) => (
            <TableRow key={report.id}>
              <TableCell className="text-sm">{report.reporterName}</TableCell>
              <TableCell>
                <Link href={`/feedback/${report.id}`} className="text-sm font-medium hover:underline">
                  {report.reportedUserName}
                </Link>
              </TableCell>
              <TableCell className="max-w-[280px] truncate text-sm text-muted-foreground">{report.reason}</TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(report.createdAt)}</TableCell>
              <TableCell>
                <StatusBadge status={report.status} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
