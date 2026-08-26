import Link from "next/link";

import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminPaymentRow } from "@/lib/data/payments";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

function formatAmount(amount: number, currency: string): string {
  return `${amount.toLocaleString("az-AZ")} ${currency}`;
}

/**
 * Dedicated view of `payments` rows where `type === "venue_premium"`
 * (see `PaymentsPage` for the general list every payment type still
 * shows up in). Columns match what an admin actually needs to check
 * for THIS payment kind specifically — duration purchased and where
 * the venue's premium period currently stands — rather than reusing
 * `PaymentsTable`'s generic shape, which has no room for either.
 */
export function PremiumPaymentsTable({ payments }: { payments: AdminPaymentRow[] }) {
  if (payments.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Hələ heç bir premium məkan ödənişi yoxdur.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Sahib</TableHead>
            <TableHead>Məkan</TableHead>
            <TableHead>Müddət</TableHead>
            <TableHead>Məbləğ</TableHead>
            <TableHead>Ödəniş tarixi</TableHead>
            <TableHead>Bitmə tarixi</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {payments.map((payment) => (
            <TableRow key={payment.id}>
              <TableCell>
                <Link href={`/users/${payment.ownerId}`} className="text-sm font-medium hover:underline">
                  {payment.ownerName}
                  {payment.ownerUsername ? <span className="text-muted-foreground"> · @{payment.ownerUsername}</span> : null}
                </Link>
              </TableCell>
              <TableCell className="text-sm">
                {payment.listingId ? (
                  <Link href={`/venues/${payment.listingId}`} className="hover:underline">
                    {payment.listingName ?? payment.listingId}
                  </Link>
                ) : (
                  <span className="text-muted-foreground">—</span>
                )}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">
                {payment.premiumMonths ? `${payment.premiumMonths} ay` : "—"}
              </TableCell>
              <TableCell className="text-sm">{formatAmount(payment.amount, payment.currency)}</TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(payment.createdAt)}</TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(payment.venuePremiumExpiresAt)}</TableCell>
              <TableCell>
                <StatusBadge status={payment.status} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
