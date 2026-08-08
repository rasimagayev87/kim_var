"use client";

import { useState, useTransition } from "react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

/**
 * Shared note-collecting dialog behind both "Düzəlişə göndər" (note
 * required) and "Sil" (note optional) — used by both venue and offer
 * moderation actions, since the two are otherwise identical UI.
 */
export function ModerationNoteDialog({
  triggerLabel,
  triggerVariant = "outline",
  disabled,
  title,
  description,
  noteRequired,
  submitLabel,
  submitVariant = "default",
  onSubmit,
}: {
  triggerLabel: string;
  triggerVariant?: "default" | "outline" | "destructive";
  disabled?: boolean;
  title: string;
  description: string;
  noteRequired: boolean;
  submitLabel: string;
  submitVariant?: "default" | "outline" | "destructive";
  onSubmit: (note: string) => Promise<boolean>;
}) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState("");
  const [pending, startTransition] = useTransition();

  function handleSubmit() {
    startTransition(async () => {
      const ok = await onSubmit(note.trim());
      if (ok) {
        setNote("");
        setOpen(false);
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Button variant={triggerVariant} disabled={disabled} onClick={() => setOpen(true)}>
        {triggerLabel}
      </Button>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <div className="space-y-2">
          <Label htmlFor="moderation-note">Səbəb{noteRequired ? "" : " (opsional)"}</Label>
          <Textarea
            id="moderation-note"
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="Sahibə göstəriləcək qeyd..."
          />
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>
            Ləğv et
          </Button>
          <Button
            variant={submitVariant}
            onClick={handleSubmit}
            disabled={pending || (noteRequired && note.trim().length === 0)}
          >
            {pending ? "Göndərilir..." : submitLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
