"use client";

import { useCallback, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function ReportsFilters({ initialStatus }: { initialStatus: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [, startTransition] = useTransition();

  const updateParam = useCallback(
    (value: string | null) => {
      const params = new URLSearchParams(searchParams.toString());
      if (value === "all" || !value) {
        params.delete("status");
      } else {
        params.set("status", value);
      }
      startTransition(() => {
        router.push(`/feedback?${params.toString()}`);
      });
    },
    [router, searchParams],
  );

  return (
    <Select defaultValue={initialStatus} onValueChange={updateParam}>
      <SelectTrigger className="sm:w-48">
        <SelectValue placeholder="Status" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="all">Hamısı</SelectItem>
        <SelectItem value="pending">Gözləyən</SelectItem>
        <SelectItem value="reviewed">Nəzərdən keçirilib</SelectItem>
        <SelectItem value="actioned">Əməliyyat edilib</SelectItem>
        <SelectItem value="dismissed">Rədd edilib</SelectItem>
      </SelectContent>
    </Select>
  );
}
