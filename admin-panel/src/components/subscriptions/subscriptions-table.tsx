import Link from "next/link";

import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { SubscriptionRow } from "@/lib/data/subscriptions";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

const STATUS_LABELS: Record<string, string> = {
  approved: "Aktiv",
  subscription_overdue: "Borclu",
  awaiting_payment: "Ödəniş gözlənilir",
};

function daysUntil(iso: string | null): number | null {
  if (!iso) return null;
  return Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000);
}

/**
 * @param showMoney comes from the page's `viewRevenue` check. When
 * false the money columns are not rendered — and the fields are absent
 * from the rows entirely, because the data layer never attached them
 * (see `listSubscriptions`). This flag only decides the header cells.
 */
export function SubscriptionsTable({
  subscriptions,
  showMoney,
}: {
  subscriptions: SubscriptionRow[];
  showMoney: boolean;
}) {
  if (subscriptions.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrə uyğun abunəlik yoxdur.
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Məkan</TableHead>
            <TableHead>Kateqoriya</TableHead>
            <TableHead>Status</TableHead>
            <TableHead>Növbəti ödəniş</TableHead>
            {showMoney ? <TableHead className="text-right">Aylıq</TableHead> : null}
            {showMoney ? <TableHead>Son ödəniş</TableHead> : null}
          </TableRow>
        </TableHeader>
        <TableBody>
          {subscriptions.map((row) => {
            const days = daysUntil(row.renewsAt);
            return (
              <TableRow key={row.venueId}>
                <TableCell className="font-medium">
                  <Link className="hover:underline" href={`/venues/${row.venueId}`}>
                    {row.venueName || row.venueId}
                  </Link>
                </TableCell>
                <TableCell className="text-sm text-muted-foreground">{row.category || "—"}</TableCell>
                <TableCell className="text-sm">
                  {row.status ? (STATUS_LABELS[row.status] ?? row.status) : "—"}
                </TableCell>
                <TableCell className="text-sm">
                  {formatDate(row.renewsAt)}
                  {days !== null && days >= 0 && days <= 7 ? (
                    <span className="ml-2 text-xs text-amber-600 dark:text-amber-400">
                      {days} gün qalıb
                    </span>
                  ) : null}
                  {days !== null && days < 0 ? (
                    <span className="ml-2 text-xs text-red-600 dark:text-red-400">gecikib</span>
                  ) : null}
                </TableCell>
                {showMoney ? (
                  <TableCell className="text-right tabular-nums">
                    {row.monthlyFeeAzn == null ? "—" : `${row.monthlyFeeAzn} AZN`}
                  </TableCell>
                ) : null}
                {showMoney ? (
                  <TableCell className="text-sm text-muted-foreground">
                    {formatDate(row.lastPaidAt ?? null)}
                  </TableCell>
                ) : null}
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </div>
  );
}
