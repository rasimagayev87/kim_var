"use client";

import { useCallback, useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function EventsFilters({
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
      if (!value) params.delete(key);
      else params.set(key, value);
      startTransition(() => {
        router.push(`/events?${params.toString()}`);
      });
    },
    [router, searchParams],
  );

  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
      <Input
        placeholder="Tədbir və ya məkan adı axtar..."
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === "Enter") updateParam("q", search);
        }}
        onBlur={() => updateParam("q", search)}
        className="sm:max-w-xs"
      />
      {/* Defaults to `pending`, not `all` — this screen exists for the
          review queue, and an empty queue is the answer a moderator
          wants to see first. */}
      <Select defaultValue={initialStatus} onValueChange={(value) => updateParam("status", value)}>
        <SelectTrigger className="sm:w-44">
          <SelectValue placeholder="Status" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="pending">Baxış gözləyən</SelectItem>
          <SelectItem value="upcoming">Yayımlanmış</SelectItem>
          <SelectItem value="live">Canlı</SelectItem>
          <SelectItem value="ended">Bitmiş</SelectItem>
          <SelectItem value="rejected">Rədd edilmiş</SelectItem>
          <SelectItem value="cancelled">Ləğv edilmiş</SelectItem>
          <SelectItem value="all">Hamısı</SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
}
