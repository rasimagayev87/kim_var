"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ModerationNoteDialog } from "@/components/moderation/moderation-note-dialog";
import { setPinBoxStatus } from "@/lib/actions/pinboxes";
import type { PinBoxStatus } from "@/lib/data/pinboxes";

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "note-required": "Səbəb xanası məcburidir.",
};

export function PinBoxStatusActions({ id, status }: { id: string; status: PinBoxStatus }) {
  const [pending, startTransition] = useTransition();

  function apply(next: PinBoxStatus, successMessage: string, note?: string) {
    startTransition(async () => {
      const result = await setPinBoxStatus(id, next, note);
      if (result.ok) {
        toast.success(successMessage);
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
      }
    });
  }

  async function applyAsync(next: PinBoxStatus, successMessage: string, note: string): Promise<boolean> {
    const result = await setPinBoxStatus(id, next, note);
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
        <Button disabled={pending} onClick={() => apply("active", "PinBox təsdiqləndi.")}>
          Təsdiq et
        </Button>
        <ModerationNoteDialog
          triggerLabel="Düzəlişə göndər"
          triggerVariant="outline"
          disabled={pending}
          title="PinBox-ı düzəlişə göndər"
          description="Sahibə göstəriləcək bu qeyd olmadan davam etmək mümkün deyil — sahib düzəldib yenidən göndərə bilər."
          noteRequired
          submitLabel="Düzəlişə göndər"
          onSubmit={(note) => applyAsync("needs_revision", "PinBox düzəlişə göndərildi.", note)}
        />
        <ModerationNoteDialog
          triggerLabel="Rədd et"
          triggerVariant="destructive"
          disabled={pending}
          title="PinBox-ı rədd et"
          description="Səbəb qeyd etmək opsionaldır — sahibə göstəriləcək. PinBox listinqinin özünün haqqı olmadığı üçün geri qaytarılacaq ödəniş yoxdur."
          noteRequired={false}
          submitLabel="Rədd et"
          submitVariant="destructive"
          onSubmit={(note) => applyAsync("rejected", "PinBox rədd edildi.", note)}
        />
      </div>
    );
  }

  if (status === "needs_revision") {
    return <p className="text-sm text-muted-foreground">Sahibin düzəliş edib yenidən göndərməsi gözlənilir.</p>;
  }

  if (status === "active") {
    return (
      <Button variant="destructive" disabled={pending} onClick={() => apply("rejected", "PinBox rədd edildi.")}>
        Rədd et
      </Button>
    );
  }

  if (status === "rejected") {
    return (
      <Button variant="outline" disabled={pending} onClick={() => apply("active", "PinBox təsdiqləndi.")}>
        Yenidən təsdiqlə
      </Button>
    );
  }

  // soldOut / expired — a terminal, buyer-driven or time-driven state;
  // nothing left for an admin to decide here.
  return <p className="text-sm text-muted-foreground">Bu qutu üzrə moderasiya tələb olunmur.</p>;
}
