"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { setVenuePremium } from "@/lib/actions/venues";

export function VenuePremiumActions({ id, isPremium }: { id: string; isPremium: boolean }) {
  const [pending, startTransition] = useTransition();

  function run(action: () => Promise<{ ok: boolean; error?: string }>, successMessage: string) {
    startTransition(async () => {
      const result = await action();
      if (result.ok) {
        toast.success(successMessage);
      } else {
        toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Əməliyyat uğursuz oldu.");
      }
    });
  }

  return (
    <div className="flex items-center justify-between">
      <Label htmlFor="venue-premium-switch" className="flex flex-col items-start gap-0.5">
        <span>Premium</span>
        <span className="text-xs font-normal text-muted-foreground">
          Ödəniş sistemi hazır olana qədər manual premium — radiusu üzrə ən öndə göstərilir
        </span>
      </Label>
      <Switch
        id="venue-premium-switch"
        checked={isPremium}
        disabled={pending}
        onCheckedChange={(checked) =>
          run(() => setVenuePremium(id, checked), checked ? "Məkan premium edildi." : "Məkanın premiumu ləğv edildi.")
        }
      />
    </div>
  );
}
