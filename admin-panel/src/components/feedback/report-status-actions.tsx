"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { setReportStatus } from "@/lib/actions/reports";
import type { ReportStatus } from "@/lib/data/reports";

export function ReportStatusActions({ id, status }: { id: string; status: ReportStatus }) {
  const [pending, startTransition] = useTransition();

  function apply(next: ReportStatus, successMessage: string) {
    startTransition(async () => {
      const result = await setReportStatus(id, next);
      if (result.ok) {
        toast.success(successMessage);
      } else {
        toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Əməliyyat uğursuz oldu.");
      }
    });
  }

  return (
    <div className="flex flex-wrap gap-2">
      <Button disabled={pending || status === "reviewed"} variant="outline" onClick={() => apply("reviewed", "Nəzərdən keçirildi olaraq işarələndi.")}>
        Nəzərdən keçirildi
      </Button>
      <Button disabled={pending || status === "actioned"} onClick={() => apply("actioned", "Əməliyyat edildi olaraq işarələndi.")}>
        Əməliyyat edildi
      </Button>
      <Button
        disabled={pending || status === "dismissed"}
        variant="ghost"
        onClick={() => apply("dismissed", "Şikayət rədd edildi.")}
      >
        Rədd et
      </Button>
    </div>
  );
}
