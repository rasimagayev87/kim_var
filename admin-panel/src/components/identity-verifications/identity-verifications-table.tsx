import Link from "next/link";

import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminIdentityVerificationRow } from "@/lib/data/identity-verifications";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function IdentityVerificationsTable({ rows }: { rows: AdminIdentityVerificationRow[] }) {
  if (rows.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrə uyğun müraciət tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>İstifadəçi</TableHead>
            <TableHead>Göndərilmə tarixi</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={row.id} className="cursor-pointer">
              <TableCell>
                <Link href={`/identity-verifications/${row.id}`} className="font-medium hover:underline">
                  {row.userName}
                  {row.userUsername ? <span className="text-muted-foreground"> · @{row.userUsername}</span> : null}
                </Link>
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(row.submittedAt)}</TableCell>
              <TableCell>
                <StatusBadge status={row.status} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
