"use client";

import { useEffect, useState, useTransition } from "react";
import { toast } from "sonner";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { countBroadcastAudience, sendBroadcast, type BroadcastSegment, type BroadcastType } from "@/lib/actions/broadcast";

const SEGMENT_LABELS: Record<BroadcastSegment, string> = {
  all: "Hamı",
  vip: "VIP istifadəçilər",
  verified: "Verified istifadəçilər",
};

export function BroadcastForm() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [type, setType] = useState<BroadcastType>("announcement");
  const [segment, setSegment] = useState<BroadcastSegment>("all");
  const [audience, setAudience] = useState<number | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const [countPending, startCountTransition] = useTransition();

  useEffect(() => {
    let cancelled = false;
    startCountTransition(async () => {
      const result = await countBroadcastAudience(segment);
      if (cancelled) return;
      setAudience(typeof result === "number" ? result : 0);
    });
    return () => {
      cancelled = true;
    };
  }, [segment]);

  const canSubmit = title.trim().length > 0 && body.trim().length > 0 && !pending;

  function handleSend() {
    setConfirmOpen(false);
    startTransition(async () => {
      const result = await sendBroadcast({ title, body, type, segment });
      if (result.ok) {
        toast.success(`Bildiriş ${result.sentCount} istifadəçiyə göndərildi.`);
        setTitle("");
        setBody("");
      } else if (result.error === "empty-audience") {
        toast.error("Bu seqmentdə istifadəçi yoxdur.");
      } else if (result.error === "invalid-input") {
        toast.error("Başlıq və mətn boş ola bilməz.");
      } else {
        toast.error("Bildiriş göndərilmədi.");
      }
    });
  }

  return (
    <>
      <div className="space-y-5">
        <div className="space-y-2">
          <Label htmlFor="broadcast-title">Başlıq</Label>
          <Input id="broadcast-title" value={title} onChange={(event) => setTitle(event.target.value)} maxLength={80} />
        </div>

        <div className="space-y-2">
          <Label htmlFor="broadcast-body">Mətn</Label>
          <Textarea
            id="broadcast-body"
            value={body}
            onChange={(event) => setBody(event.target.value)}
            rows={4}
            maxLength={500}
          />
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-2">
            <Label>Bildiriş növü</Label>
            <Select value={type} onValueChange={(value) => setType(value as BroadcastType)}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="announcement">Elan (announcement)</SelectItem>
                <SelectItem value="promotion">Təklif (promotion)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>Hədəf seqment</Label>
            <Select value={segment} onValueChange={(value) => setSegment(value as BroadcastSegment)}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Hamı</SelectItem>
                <SelectItem value="vip">VIP istifadəçilər</SelectItem>
                <SelectItem value="verified">Verified istifadəçilər</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <p className="text-sm text-muted-foreground">
          {countPending || audience === null
            ? "Hədəf sayı hesablanır..."
            : `${audience} istifadəçiyə göndəriləcək.`}
        </p>

        <Button className="w-full" disabled={!canSubmit} onClick={() => setConfirmOpen(true)}>
          {pending ? "Göndərilir..." : "Göndər"}
        </Button>
      </div>

      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Bildirişi göndər?</AlertDialogTitle>
            <AlertDialogDescription>
              &quot;{title}&quot; başlıqlı bildiriş <strong>{SEGMENT_LABELS[segment]}</strong> seqmentinə (
              {audience ?? "…"} istifadəçi) göndəriləcək. Bu əməliyyat geri qaytarıla bilməz.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Ləğv et</AlertDialogCancel>
            <AlertDialogAction onClick={handleSend}>Göndər</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
