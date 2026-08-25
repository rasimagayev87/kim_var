"use client";

import { useCallback, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function PinBoxPayoutsFilters({ initialStatus }: { initialStatus: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [, startTransition] = useTransition();

  const updateStatus = useCallback(
    (value: string | null) => {
      const params = new URLSearchParams(searchParams.toString());
      // Deliberately NOT deleting the param for "all" — the page's own
      // default (no `status` in the URL) is "pending", the actionable
      // queue, not "hamısı". Deleting here would silently bounce a user
      // who picked "Hamısı" straight back to that queue.
      params.set("status", value ?? "all");
      startTransition(() => {
        router.push(`/pinbox-payouts?${params.toString()}`);
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
        <SelectItem value="pending">Ödənilməli</SelectItem>
        <SelectItem value="all">Hamısı</SelectItem>
        <SelectItem value="paid">Ödənilmiş</SelectItem>
      </SelectContent>
    </Select>
  );
}
