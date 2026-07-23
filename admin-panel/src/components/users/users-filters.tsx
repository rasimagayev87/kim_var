"use client";

import { useCallback, useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function UsersFilters({
  initialSearch,
  initialVerified,
  initialVip,
}: {
  initialSearch: string;
  initialVerified: string;
  initialVip: string;
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
        router.push(`/users?${params.toString()}`);
      });
    },
    [router, searchParams],
  );

  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
      <Input
        placeholder="Username, ad və ya telefon axtar..."
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === "Enter") updateParam("q", search);
        }}
        onBlur={() => updateParam("q", search)}
        className="sm:max-w-xs"
      />
      <Select defaultValue={initialVerified} onValueChange={(value) => updateParam("verified", value)}>
        <SelectTrigger className="sm:w-44">
          <SelectValue placeholder="Verified statusu" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Hamısı</SelectItem>
          <SelectItem value="verified">Verified</SelectItem>
          <SelectItem value="unverified">Unverified</SelectItem>
        </SelectContent>
      </Select>
      <Select defaultValue={initialVip} onValueChange={(value) => updateParam("vip", value)}>
        <SelectTrigger className="sm:w-36">
          <SelectValue placeholder="VIP statusu" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Hamısı</SelectItem>
          <SelectItem value="vip">VIP</SelectItem>
          <SelectItem value="free">Free</SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
}
