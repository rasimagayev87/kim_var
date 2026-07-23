"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { setOfferStatus } from "@/lib/actions/offers";
import type { OfferStatus } from "@/lib/data/offers";

export function OfferStatusActions({ id, status }: { id: string; status: OfferStatus }) {
  const [pending, startTransition] = useTransition();

  function apply(next: OfferStatus, successMessage: string) {
    startTransition(async () => {
      const result = await setOfferStatus(id, next);
      if (result.ok) {
        toast.success(successMessage);
      } else {
        toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Əməliyyat uğursuz oldu.");
      }
    });
  }

  if (status === "pending") {
    return (
      <div className="flex gap-2">
        <Button disabled={pending} onClick={() => apply("active", "Təklif təsdiqləndi.")}>
          Təsdiqlə
        </Button>
        <Button variant="destructive" disabled={pending} onClick={() => apply("rejected", "Təklif rədd edildi.")}>
          Rədd et
        </Button>
      </div>
    );
  }

  if (status === "active") {
    return (
      <Button variant="destructive" disabled={pending} onClick={() => apply("rejected", "Təklif rədd edildi.")}>
        Rədd et
      </Button>
    );
  }

  // rejected — still recoverable, in case a rejection was a mistake.
  return (
    <Button variant="outline" disabled={pending} onClick={() => apply("active", "Təklif təsdiqləndi.")}>
      Yenidən təsdiqlə
    </Button>
  );
}
