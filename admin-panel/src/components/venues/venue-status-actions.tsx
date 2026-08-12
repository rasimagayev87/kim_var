"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ModerationNoteDialog } from "@/components/moderation/moderation-note-dialog";
import { setVenueStatus } from "@/lib/actions/venues";
import type { VenueStatus } from "@/lib/data/venues";

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "note-required": "Səbəb xanası məcburidir.",
};

export function VenueStatusActions({
  id,
  status,
  revisionDeadlineDaysLeft,
}: {
  id: string;
  status: VenueStatus;
  /** Computed server-side (see the venue detail page) — avoids a
   * client-side `Date.now()` call during render. */
  revisionDeadlineDaysLeft?: number | null;
}) {
  const [pending, startTransition] = useTransition();

  function apply(next: VenueStatus, successMessage: string, note?: string) {
    startTransition(async () => {
      const result = await setVenueStatus(id, next, note);
      if (result.ok) {
        toast.success(successMessage);
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
      }
    });
  }

  async function applyAsync(next: VenueStatus, successMessage: string, note: string): Promise<boolean> {
    const result = await setVenueStatus(id, next, note);
    if (result.ok) {
      toast.success(successMessage);
      return true;
    }
    toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
    return false;
  }

  if (status === "pending") {
    return (
      <div className="flex flex-wrap gap-2">
        <Button disabled={pending} onClick={() => apply("approved", "Məkan təsdiqləndi.")}>
          Qəbul et
        </Button>
        <ModerationNoteDialog
          triggerLabel="Düzəlişə göndər"
          triggerVariant="outline"
          disabled={pending}
          title="Məkanı düzəlişə göndər"
          description="Sahibə göstəriləcək bu qeyd olmadan davam etmək mümkün deyil. Sahibə 7 gün vaxt veriləcək — bu müddətdə düzəldib göndərməsə, ödənişi avtomatik geri qaytarılmaq üçün işarələnəcək."
          noteRequired
          submitLabel="Düzəlişə göndər"
          onSubmit={(note) => applyAsync("needs_revision", "Məkan düzəlişə göndərildi.", note)}
        />
        <ModerationNoteDialog
          triggerLabel="Rədd et və pulu qaytar"
          triggerVariant="destructive"
          disabled={pending}
          title="Məkanı rədd et"
          description="Səbəb qeyd etmək opsionaldır. Ödəniş varsa, geri qaytarılmaq üçün Ödənişlər səhifəsindəki əl-ilə-izləmə siyahısına düşəcək."
          noteRequired={false}
          submitLabel="Rədd et"
          submitVariant="destructive"
          onSubmit={(note) => applyAsync("rejected", "Məkan rədd edildi.", note)}
        />
      </div>
    );
  }

  if (status === "needs_revision") {
    return (
      <p className="text-sm text-muted-foreground">
        Sahibin düzəliş edib yenidən göndərməsi gözlənilir.
        {revisionDeadlineDaysLeft != null &&
          ` ${revisionDeadlineDaysLeft} gün qaldı — bitəndə avtomatik rədd olunub pulu geri qaytarılacaq.`}
      </p>
    );
  }

  if (status === "approved") {
    return (
      <Button variant="outline" disabled={pending} onClick={() => apply("inactive", "Məkan deaktiv edildi.")}>
        Deaktiv et
      </Button>
    );
  }

  if (status === "inactive") {
    return (
      <Button disabled={pending} onClick={() => apply("approved", "Məkan aktiv edildi.")}>
        Aktiv et
      </Button>
    );
  }

  // rejected — still recoverable, in case a rejection was a mistake.
  return (
    <Button variant="outline" disabled={pending} onClick={() => apply("approved", "Məkan aktiv edildi.")}>
      Yenidən aktiv et
    </Button>
  );
}
