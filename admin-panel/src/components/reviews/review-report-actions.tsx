"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { dismissReviewReport, resolveReviewReport } from "@/lib/actions/review-reports";
import type { ReviewReportStatus } from "@/lib/data/review-reports";

export function ReviewReportActions({
  reportId,
  reviewId,
  status,
  reviewDeleted,
}: {
  reportId: string;
  reviewId: string;
  status: ReviewReportStatus;
  reviewDeleted: boolean;
}) {
  const [pending, startTransition] = useTransition();

  function resolve() {
    startTransition(async () => {
      const result = await resolveReviewReport(reportId, reviewId);
      if (result.ok) {
        toast.success("Rəy silindi, şikayət həll edildi.");
      } else {
        toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Əməliyyat uğursuz oldu.");
      }
    });
  }

  function dismiss() {
    startTransition(async () => {
      const result = await dismissReviewReport(reportId);
      if (result.ok) {
        toast.success("Şikayət rədd edildi.");
      } else {
        toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Əməliyyat uğursuz oldu.");
      }
    });
  }

  if (status !== "pending") return null;

  return (
    <div className="flex flex-wrap gap-2">
      <Button disabled={pending || reviewDeleted} variant="destructive" onClick={resolve}>
        Sil
      </Button>
      <Button disabled={pending} variant="ghost" onClick={dismiss}>
        Rədd et
      </Button>
    </div>
  );
}
