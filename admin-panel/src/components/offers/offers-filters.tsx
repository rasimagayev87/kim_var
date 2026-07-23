"use client";

import { useCallback, useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function OffersFilters({
  initialSearch,
  initialStatus,
}: {
  initialSearch: string;
  initialStatus: string;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [search, setSearch] = useState(initialSearch);
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
        router.push(`/offers?${params.toString()}`);
      });
    },
    [router, searchParams],
  );

  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
      <Input
        placeholder="Təklif və ya məkan adı axtar..."
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === "Enter") updateParam("q", search);
        }}
        onBlur={() => updateParam("q", search)}
        className="sm:max-w-xs"
      />
      <Select defaultValue={initialStatus} onValueChange={(value) => updateParam("status", value)}>
        <SelectTrigger className="sm:w-44">
          <SelectValue placeholder="Status" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Hamısı</SelectItem>
          <SelectItem value="pending">Gözləyən</SelectItem>
          <SelectItem value="active">Aktiv</SelectItem>
          <SelectItem value="rejected">Rədd edilib</SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
}
