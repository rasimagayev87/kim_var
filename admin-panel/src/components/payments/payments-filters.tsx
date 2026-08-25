"use client";

import { useCallback, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function PaymentsFilters({ initialStatus }: { initialStatus: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [, startTransition] = useTransition();

  const updateStatus = useCallback(
    (value: string | null) => {
      const params = new URLSearchParams(searchParams.toString());
      // Deliberately NOT deleting the param for "all" — the page's own
      // default (no `status` in the URL) is "refund_pending", the
      // actionable queue, not "hamısı". Deleting here would silently
      // bounce a user who picked "Hamısı" straight back to that queue.
      params.set("status", value ?? "all");
      startTransition(() => {
        router.push(`/payments?${params.toString()}`);
      });
    },
    [router, searchParams],
  );

  return (
    <Select defaultValue={initialStatus} onValueChange={updateStatus}>
      <SelectTrigger className="sm:w-56">
        <SelectValue placeholder="Status" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="refund_pending">Geri qaytarılmalı</SelectItem>
        <SelectItem value="all">Hamısı</SelectItem>
        <SelectItem value="completed">Ödənilib</SelectItem>
        <SelectItem value="pending">Gözləyən</SelectItem>
        <SelectItem value="failed">Uğursuz</SelectItem>
        <SelectItem value="revision_pending">Düzəliş gözlənilir</SelectItem>
        <SelectItem value="refunded">Geri qaytarılıb</SelectItem>
      </SelectContent>
    </Select>
  );
}
