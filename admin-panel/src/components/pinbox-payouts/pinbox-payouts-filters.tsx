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
      if (!value || value === "all") {
        params.delete("status");
      } else {
        params.set("status", value);
      }
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
        <SelectItem value="paid">Ödənilib</SelectItem>
      </SelectContent>
    </Select>
  );
}
