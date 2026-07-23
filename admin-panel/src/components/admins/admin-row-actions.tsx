"use client";

import { useTransition } from "react";
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
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { changeAdminRole, removeAdmin } from "@/lib/actions/admins";
import type { AdminRosterRow } from "@/lib/data/admins";

const ERROR_MESSAGES: Record<string, string> = {
  "cannot-change-self": "Öz rolunuzu dəyişə və ya özünüzü silə bilməzsiniz — başqa bir admin bunu etməlidir.",
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
};

export function AdminRowActions({ admin }: { admin: AdminRosterRow }) {
  const [pending, startTransition] = useTransition();
  const otherRole = admin.role === "admin" ? "moderator" : "admin";

  function handleRoleChange() {
    startTransition(async () => {
      const result = await changeAdminRole(admin.uid, otherRole);
      if (result.ok) {
        toast.success(`Rol ${otherRole} olaraq dəyişdirildi.`);
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Rol dəyişdirilmədi.");
      }
    });
  }

  function handleRemove() {
    startTransition(async () => {
      const result = await removeAdmin(admin.uid);
      if (result.ok) {
        toast.success(`${admin.email} silindi.`);
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Silinmədi.");
      }
    });
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger render={<Button variant="ghost" size="sm" disabled={pending} />}>
        Əməliyyatlar
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={handleRoleChange}>
          {otherRole === "admin" ? "Admin et" : "Moderator et"}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <AlertDialog>
          <AlertDialogTrigger render={<DropdownMenuItem variant="destructive" onSelect={(event) => event.preventDefault()} />}>
            Sil
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>{admin.email} silinsin?</AlertDialogTitle>
              <AlertDialogDescription>
                Bu hesabın admin panelə girişi dərhal ləğv ediləcək (mövcud sessiyaları da daxil olmaqla).
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Ləğv et</AlertDialogCancel>
              <AlertDialogAction onClick={handleRemove}>Sil</AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
