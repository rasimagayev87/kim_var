"use client";

import { useTransition } from "react";
import Link from "next/link";
import { MoreHorizontal } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { setUserBanned, setUserPremium, setUserVerified } from "@/lib/actions/users";
import type { AdminUserRow } from "@/lib/data/users";

export function UserRowActions({ user }: { user: AdminUserRow }) {
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
    <DropdownMenu>
      <DropdownMenuTrigger
        render={
          <Button variant="ghost" size="icon" disabled={pending}>
            <MoreHorizontal className="size-4" />
          </Button>
        }
      />
      <DropdownMenuContent align="end">
        <DropdownMenuItem render={<Link href={`/users/${user.uid}`}>Profilə bax</Link>} />
        <DropdownMenuSeparator />
        <DropdownMenuItem
          onClick={() =>
            run(
              () => setUserVerified(user.uid, !user.isVerified),
              user.isVerified ? "Verified status ləğv edildi." : "İstifadəçi verified edildi.",
            )
          }
        >
          {user.isVerified ? "Verified-i ləğv et" : "Verified et"}
        </DropdownMenuItem>
        <DropdownMenuItem
          onClick={() =>
            run(
              () => setUserPremium(user.uid, !user.premium),
              user.premium ? "VIP status ləğv edildi." : "İstifadəçi VIP edildi.",
            )
          }
        >
          {user.premium ? "VIP-i ləğv et" : "VIP et"}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          variant="destructive"
          onClick={() =>
            run(
              () => setUserBanned(user.uid, !user.banned),
              user.banned ? "Ban aradan qaldırıldı." : "İstifadəçi ban edildi.",
            )
          }
        >
          {user.banned ? "Blokdan çıxar" : "Ban et"}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
