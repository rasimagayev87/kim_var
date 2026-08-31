"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ModerationNoteDialog } from "@/components/moderation/moderation-note-dialog";
import { deleteEvent, resetEventTrust, setEventStatus } from "@/lib/actions/events";
import type { EventStatus } from "@/lib/data/events";

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "note-required": "Səbəb xanası məcburidir.",
  "not-pending": "Bu tədbir artıq baxılıb.",
  "not-found": "Tədbir tapılmadı.",
};

function reportError(error?: string) {
  toast.error(ERROR_MESSAGES[error ?? ""] ?? "Əməliyyat uğursuz oldu.");
}

export function EventStatusActions({
  id,
  venueId,
  status,
}: {
  id: string;
  venueId: string;
  status: EventStatus;
}) {
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  async function applyAsync(next: "upcoming" | "rejected", message: string, note: string): Promise<boolean> {
    const result = await setEventStatus(id, next, note);
    if (result.ok) {
      toast.success(message);
      return true;
    }
    reportError(result.error);
    return false;
  }

  return (
    <div className="flex flex-wrap gap-2">
      {status === "pending" && (
        <>
          <Button
            disabled={pending}
            onClick={() =>
              startTransition(async () => {
                const result = await setEventStatus(id, "upcoming");
                if (result.ok) toast.success("Tədbir yayımlandı.");
                else reportError(result.error);
              })
            }
          >
            Təsdiqlə və yayımla
          </Button>
          <ModerationNoteDialog
            triggerLabel="Rədd et"
            triggerVariant="destructive"
            disabled={pending}
            title="Tədbiri rədd et"
            // Required, unlike an offer rejection: an event that
            // disappears with no reason leaves the owner with nothing to
            // act on, and the owner is notified of this decision.
            description="Səbəb məcburidir — sahibə bildirişlə göndəriləcək."
            noteRequired
            submitLabel="Rədd et"
            submitVariant="destructive"
            onSubmit={(note) => applyAsync("rejected", "Tədbir rədd edildi.", note)}
          />
        </>
      )}

      {/* Takedown, available in any state — the parity offers, PinBoxes
          and venues already have. */}
      <Button
        variant="destructive"
        disabled={pending}
        onClick={() =>
          startTransition(async () => {
            const result = await deleteEvent(id);
            if (result.ok) {
              toast.success("Tədbir silindi.");
              router.push("/events");
            } else reportError(result.error);
          })
        }
      >
        Sil
      </Button>

      {/* Puts this venue's events back under review. Deliberately a
          separate, logged decision rather than a side-effect of the
          venue being re-approved — see `resetEventTrust`. */}
      <Button
        variant="outline"
        disabled={pending}
        onClick={() =>
          startTransition(async () => {
            const result = await resetEventTrust(venueId);
            if (result.ok) toast.success("Məkanın tədbir etimadı sıfırlandı — növbəti 3 tədbir baxışa düşəcək.");
            else reportError(result.error);
          })
        }
      >
        Etimadı sıfırla
      </Button>
    </div>
  );
}
