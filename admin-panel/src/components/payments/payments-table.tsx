"use client";

import Link from "next/link";
import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { markPaymentRefunded } from "@/lib/actions/payments";
import type { AdminPaymentRow } from "@/lib/data/payments";

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "not-found": "Ödəniş tapılmadı.",
  "not-refund-pending": "Bu ödəniş artıq geri qaytarılıb, ya da geri qaytarılmalı statusunda deyil.",
};

const TYPE_LABELS: Record<string, string> = {
  venue_listing: "Məkan elanı",
};

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

function formatAmount(amount: number, currency: string): string {
  return `${amount.toLocaleString("az-AZ")} ${currency}`;
}

export function PaymentsTable({ payments }: { payments: AdminPaymentRow[] }) {
  const [pending, startTransition] = useTransition();

  function handleMarkRefunded(id: string) {
    startTransition(async () => {
      const result = await markPaymentRefunded(id);
      if (result.ok) {
        toast.success("Ödəniş geri qaytarıldı kimi işarələndi.");
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
      }
    });
  }

  if (payments.length === 0) {
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
            <TableHead>Sahib</TableHead>
            <TableHead>Məkan</TableHead>
            <TableHead>Növ</TableHead>
            <TableHead>Məbləğ</TableHead>
            <TableHead>Tarix</TableHead>
            <TableHead>Status</TableHead>
            <TableHead />
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
                {payment.venueId ? (
                  <Link href={`/venues/${payment.venueId}`} className="hover:underline">
                    {payment.venueName ?? payment.venueId}
                  </Link>
                ) : (
                  <span className="text-muted-foreground">—</span>
                )}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{TYPE_LABELS[payment.type] ?? payment.type}</TableCell>
              <TableCell className="text-sm">{formatAmount(payment.amount, payment.currency)}</TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(payment.createdAt)}</TableCell>
              <TableCell>
                <StatusBadge status={payment.status} />
              </TableCell>
              <TableCell>
                {payment.status === "refund_pending" && (
                  <Button size="sm" variant="outline" disabled={pending} onClick={() => handleMarkRefunded(payment.id)}>
                    Geri qaytarıldı kimi işarələ
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
