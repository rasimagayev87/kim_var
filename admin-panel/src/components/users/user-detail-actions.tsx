"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { ModerationNoteDialog } from "@/components/moderation/moderation-note-dialog";
import { sendUserWarning, setUserBanned, setUserIdentityVerified, setUserPremium } from "@/lib/actions/users";
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

  async function warn(reason: string): Promise<boolean> {
    const result = await sendUserWarning(user.uid, reason);
    if (result.ok) {
      toast.success("Xəbərdarlıq göndərildi.");
    } else {
      toast.error(result.error === "forbidden" ? "Bu əməliyyat üçün icazəniz yoxdur." : "Xəbərdarlıq göndərilmədi.");
    }
    return result.ok;
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <Label htmlFor="verified-switch" className="flex flex-col items-start gap-0.5">
          <span>Kimlik nişanı</span>
          <span className="text-xs font-normal text-muted-foreground">Profildə mavi tik göstərir</span>
        </Label>
        <Switch
          id="verified-switch"
          checked={user.identityVerified}
          disabled={pending}
          onCheckedChange={(checked) =>
            run(
              () => setUserIdentityVerified(user.uid, checked),
              checked ? "İstifadəçiyə kimlik nişanı verildi." : "Kimlik nişanı ləğv edildi.",
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

      <ModerationNoteDialog
        triggerLabel="Xəbərdarlıq göndər"
        triggerVariant="outline"
        disabled={pending}
        title="İstifadəçiyə xəbərdarlıq göndər"
        description="Bu, ban deyil — istifadəçi bildiriş kimi görəcək. Səbəbi aydın yazın."
        noteRequired
        submitLabel="Göndər"
        onSubmit={warn}
      />

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
