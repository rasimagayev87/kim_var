"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { setVenueStatus } from "@/lib/actions/venues";
import type { VenueStatus } from "@/lib/data/venues";

export function VenueStatusActions({ id, status }: { id: string; status: VenueStatus }) {
  const [pending, startTransition] = useTransition();

  function apply(next: VenueStatus, successMessage: string) {
    startTransition(async () => {
      const result = await setVenueStatus(id, next);
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
        <Button disabled={pending} onClick={() => apply("active", "Məkan təsdiqləndi.")}>
          Təsdiqlə
        </Button>
        <Button variant="destructive" disabled={pending} onClick={() => apply("rejected", "Məkan rədd edildi.")}>
          Rədd et
        </Button>
      </div>
    );
  }

  if (status === "active") {
    return (
      <Button variant="outline" disabled={pending} onClick={() => apply("inactive", "Məkan deaktiv edildi.")}>
        Deaktiv et
      </Button>
    );
  }

  if (status === "inactive") {
    return (
      <Button disabled={pending} onClick={() => apply("active", "Məkan aktiv edildi.")}>
        Aktiv et
      </Button>
    );
  }

  // rejected — still recoverable, in case a rejection was a mistake.
  return (
    <Button variant="outline" disabled={pending} onClick={() => apply("active", "Məkan aktiv edildi.")}>
      Yenidən aktiv et
    </Button>
  );
}
