"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { dismissEventReport, resolveEventReport } from "@/lib/actions/event-reports";
import type { EventReportStatus } from "@/lib/data/event-reports";

export function EventReportActions({ reportId, eventId, status }: { reportId: string; eventId: string; status: EventReportStatus }) {
  const [pending, startTransition] = useTransition();

  function resolve() {
    startTransition(async () => {
      const result = await resolveEventReport(reportId, eventId);
      if (result.ok) {
        toast.success("Tədbir silindi, şikayət həll edildi.");
      } else {
        toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Əməliyyat uğursuz oldu.");
      }
    });
  }

  function dismiss() {
    startTransition(async () => {
      const result = await dismissEventReport(reportId);
      if (result.ok) {
        toast.success("Şikayət rədd edildi.");
      } else {
        toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Əməliyyat uğursuz oldu.");
      }
    });
  }

  if (status !== "open") return null;

  return (
    <div className="flex flex-wrap gap-2">
      <Button disabled={pending} variant="destructive" onClick={resolve}>
        Sil
      </Button>
      <Button disabled={pending} variant="ghost" onClick={dismiss}>
        Rədd et
      </Button>
    </div>
  );
}
