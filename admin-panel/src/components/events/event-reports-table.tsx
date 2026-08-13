import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminEventReportRow } from "@/lib/data/event-reports";
import { EventReportActions } from "./event-report-actions";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function EventReportsTable({ reports }: { reports: AdminEventReportRow[] }) {
  if (reports.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrə uyğun tədbir şikayəti tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Tədbir</TableHead>
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
              <TableCell className="text-sm font-medium">
                {report.eventTitle}
                <div className="mt-0.5">
                  <StatusBadge status={report.eventStatus} />
                </div>
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{report.venueName || "—"}</TableCell>
              <TableCell className="text-sm">{report.reporterName}</TableCell>
              <TableCell className="max-w-[220px] truncate text-sm text-muted-foreground">{report.reason}</TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(report.createdAt)}</TableCell>
              <TableCell>
                <StatusBadge status={report.status} />
              </TableCell>
              <TableCell>
                <EventReportActions reportId={report.id} eventId={report.eventId} status={report.status} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
