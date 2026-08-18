"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { ModerationNoteDialog } from "@/components/moderation/moderation-note-dialog";
import { setIdentityVerificationStatus } from "@/lib/actions/identity-verifications";
import type { IdentityVerificationStatus } from "@/lib/data/identity-verifications";

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "note-required": "Səbəb xanası məcburidir.",
  "not-pending": "Bu müraciət artıq nəzərdən keçirilib.",
};

export function IdentityVerificationStatusActions({ id, status }: { id: string; status: IdentityVerificationStatus }) {
  const [pending, startTransition] = useTransition();

  function approve() {
    startTransition(async () => {
      const result = await setIdentityVerificationStatus(id, "approved");
      if (result.ok) {
        toast.success("Kimlik doğrulandı — istifadəçidə mavi tık nişanı görünəcək.");
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
      }
    });
  }

  async function reject(reason: string): Promise<boolean> {
    const result = await setIdentityVerificationStatus(id, "rejected", reason);
    if (result.ok) {
      toast.success("Müraciət rədd edildi.");
      return true;
    }
    toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əməliyyat uğursuz oldu.");
    return false;
  }

  if (status !== "pending") {
    return <p className="text-sm text-muted-foreground">Bu müraciət artıq nəzərdən keçirilib.</p>;
  }

  return (
    <div className="flex flex-wrap gap-2">
      <Button disabled={pending} onClick={approve}>
        Təsdiqlə
      </Button>
      <ModerationNoteDialog
        triggerLabel="Rədd et"
        triggerVariant="destructive"
        disabled={pending}
        title="Müraciəti rədd et"
        description="İstifadəçiyə göstəriləcək bu səbəb olmadan davam etmək mümkün deyil — hansı sənədin/nə üçün uyğun olmadığını qeyd edin."
        noteRequired
        submitLabel="Rədd et"
        submitVariant="destructive"
        onSubmit={reject}
      />
    </div>
  );
}
