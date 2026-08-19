"use client";

import Link from "next/link";
import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { markPinBoxPayoutPaid } from "@/lib/actions/pinbox-payouts";
import type { AdminPinBoxPayoutRow } from "@/lib/data/pinbox-payouts";

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "not-found": "Ödəniş tapılmadı.",
  "not-pending": "Bu ödəniş artıq ödənilib.",
};

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

function formatAmount(amount: number, currency: string): string {
  return `${amount.toLocaleString("az-AZ", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${currency}`;
}

export function PinBoxPayoutsTable({ payouts }: { payouts: AdminPinBoxPayoutRow[] }) {
  const [pending, startTransition] = useTransition();

  function handleMarkPaid(id: string) {
    startTransition(async () => {
      const result = await markPinBoxPayoutPaid(id);
      if (result.ok) {
        toast.success("Ödəniş ödənildi kimi işarələndi.");
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
      }
    });
  }

  if (payouts.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrə uyğun ödəniş tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Məkan</TableHead>
            <TableHead>Sahib</TableHead>
            <TableHead>Dövr</TableHead>
            <TableHead>Sifariş sayı</TableHead>
            <TableHead>Ümumi məbləğ</TableHead>
            <TableHead>Komissiya (15%)</TableHead>
            <TableHead>Ödəniləcək</TableHead>
            <TableHead>Yaradılıb</TableHead>
            <TableHead>Status</TableHead>
            <TableHead />
          </TableRow>
        </TableHeader>
        <TableBody>
          {payouts.map((payout) => (
            <TableRow key={payout.id}>
              <TableCell>
                <Link href={`/venues/${payout.venueId}`} className="text-sm font-medium hover:underline">
                  {payout.venueName}
                </Link>
              </TableCell>
              <TableCell className="text-sm">
                {payout.ownerId ? (
                  <Link href={`/users/${payout.ownerId}`} className="hover:underline">
                    {payout.ownerName}
                    {payout.ownerUsername ? <span className="text-muted-foreground"> · @{payout.ownerUsername}</span> : null}
                  </Link>
                ) : (
                  <span className="text-muted-foreground">—</span>
                )}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{payout.period}</TableCell>
              <TableCell className="text-sm">{payout.orderCount}</TableCell>
              <TableCell className="text-sm">{formatAmount(payout.grossAmount, payout.currency)}</TableCell>
              <TableCell className="text-sm text-muted-foreground">
                {formatAmount(payout.commissionAmount, payout.currency)}
              </TableCell>
              <TableCell className="text-sm font-medium">{formatAmount(payout.payoutAmount, payout.currency)}</TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(payout.createdAt)}</TableCell>
              <TableCell>
                <StatusBadge status={payout.status} />
              </TableCell>
              <TableCell>
                {payout.status === "pending" && (
                  <Button size="sm" variant="outline" disabled={pending} onClick={() => handleMarkPaid(payout.id)}>
                    Ödənildi kimi işarələ
                  </Button>
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
