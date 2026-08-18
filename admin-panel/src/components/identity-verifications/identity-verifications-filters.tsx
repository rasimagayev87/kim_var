"use client";

import { useCallback, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function IdentityVerificationsFilters({ initialStatus }: { initialStatus: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [, startTransition] = useTransition();

  const updateParam = useCallback(
    (key: string, value: string | null) => {
      const params = new URLSearchParams(searchParams.toString());
      if (value === "all" || !value) {
        params.delete(key);
      } else {
        params.set(key, value);
      }
      startTransition(() => {
        router.push(`/identity-verifications?${params.toString()}`);
      });
    },
    [router, searchParams],
  );

  return (
    <Select defaultValue={initialStatus} onValueChange={(value) => updateParam("status", value)}>
      <SelectTrigger className="sm:w-44">
        <SelectValue placeholder="Status" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="all">Hamısı</SelectItem>
        <SelectItem value="pending">Gözləyən</SelectItem>
        <SelectItem value="approved">Təsdiqlənib</SelectItem>
        <SelectItem value="rejected">Rədd edilib</SelectItem>
      </SelectContent>
    </Select>
  );
}
