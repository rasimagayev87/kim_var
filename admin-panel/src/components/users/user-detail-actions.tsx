"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { setUserBanned, setUserPremium, setUserVerified } from "@/lib/actions/users";
import type { AdminUserRow } from "@/lib/data/users";

export function UserDetailActions({ user }: { user: AdminUserRow }) {
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
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <Label htmlFor="verified-switch" className="flex flex-col items-start gap-0.5">
          <span>Verified</span>
          <span className="text-xs font-normal text-muted-foreground">Telefon təsdiqi statusu</span>
        </Label>
        <Switch
          id="verified-switch"
          checked={user.isVerified}
          disabled={pending}
          onCheckedChange={(checked) =>
            run(
              () => setUserVerified(user.uid, checked),
              checked ? "İstifadəçi verified edildi." : "Verified status ləğv edildi.",
            )
          }
        />
      </div>

      <div className="flex items-center justify-between">
        <Label htmlFor="vip-switch" className="flex flex-col items-start gap-0.5">
          <span>VIP</span>
          <span className="text-xs font-normal text-muted-foreground">Dəstək məqsədilə manual VIP</span>
        </Label>
        <Switch
          id="vip-switch"
          checked={user.premium}
          disabled={pending}
          onCheckedChange={(checked) =>
            run(() => setUserPremium(user.uid, checked), checked ? "İstifadəçi VIP edildi." : "VIP status ləğv edildi.")
          }
        />
      </div>

      <Button
        variant={user.banned ? "outline" : "destructive"}
        className="w-full"
        disabled={pending}
        onClick={() =>
          run(
            () => setUserBanned(user.uid, !user.banned),
            user.banned ? "Ban aradan qaldırıldı." : "İstifadəçi ban edildi.",
          )
        }
      >
        {user.banned ? "Blokdan çıxar" : "Ban et"}
      </Button>
    </div>
  );
}
