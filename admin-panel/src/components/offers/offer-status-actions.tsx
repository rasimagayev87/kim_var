"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ModerationNoteDialog } from "@/components/moderation/moderation-note-dialog";
import { setOfferStatus } from "@/lib/actions/offers";
import type { OfferStatus } from "@/lib/data/offers";

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "note-required": "Səbəb xanası məcburidir.",
};

export function OfferStatusActions({ id, status }: { id: string; status: OfferStatus }) {
  const [pending, startTransition] = useTransition();

  function apply(next: OfferStatus, successMessage: string, note?: string) {
    startTransition(async () => {
      const result = await setOfferStatus(id, next, note);
      if (result.ok) {
        toast.success(successMessage);
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
      }
    });
  }

  async function applyAsync(next: OfferStatus, successMessage: string, note: string): Promise<boolean> {
    const result = await setOfferStatus(id, next, note);
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
        <Button disabled={pending} onClick={() => apply("approved", "Təklif təsdiqləndi.")}>
          Qəbul et
        </Button>
        <ModerationNoteDialog
          triggerLabel="Düzəlişə göndər"
          triggerVariant="outline"
          disabled={pending}
          title="Təklifi düzəlişə göndər"
          description="Sahibə göstəriləcək bu qeyd olmadan davam etmək mümkün deyil."
          noteRequired
          submitLabel="Düzəlişə göndər"
          onSubmit={(note) => applyAsync("needs_revision", "Təklif düzəlişə göndərildi.", note)}
        />
        <ModerationNoteDialog
          triggerLabel="Sil"
          triggerVariant="destructive"
          disabled={pending}
          title="Təklifi sil"
          description="Səbəb qeyd etmək opsionaldır."
          noteRequired={false}
          submitLabel="Sil"
          submitVariant="destructive"
          onSubmit={(note) => applyAsync("rejected", "Təklif silindi.", note)}
        />
      </div>
    );
  }

  if (status === "needs_revision") {
    return <p className="text-sm text-muted-foreground">Sahibin düzəliş edib yenidən göndərməsi gözlənilir.</p>;
  }

  if (status === "approved") {
    return (
      <Button variant="destructive" disabled={pending} onClick={() => apply("rejected", "Təklif rədd edildi.")}>
        Rədd et
      </Button>
    );
  }

  // rejected — still recoverable, in case a rejection was a mistake.
  return (
    <Button variant="outline" disabled={pending} onClick={() => apply("approved", "Təklif təsdiqləndi.")}>
      Yenidən təsdiqlə
    </Button>
  );
}
