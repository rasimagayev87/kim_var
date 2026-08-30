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
import { ROLE_LABELS } from "@/lib/auth/role-labels";
import { ADMIN_ROLES, type AdminRole } from "@/lib/auth/roles";
import type { AdminRosterRow } from "@/lib/data/admins";

const ERROR_MESSAGES: Record<string, string> = {
  "cannot-change-self": "Öz rolunuzu dəyişə və ya özünüzü silə bilməzsiniz — başqa bir admin bunu etməlidir.",
  "last-admin": "Bu, sonuncu admin hesabıdır — rolu dəyişdirilə və ya silinə bilməz. Əvvəlcə ikinci admin əlavə edin.",
  "invalid-role": "Naməlum rol seçildi.",
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
};

export function AdminRowActions({ admin }: { admin: AdminRosterRow }) {
  const [pending, startTransition] = useTransition();
  // With five roles a two-way toggle no longer expresses the choice —
  // one menu entry per role the account does NOT currently hold. An
  // unknown stored role (see `AdminRosterRow.role`) matches none of
  // them, so every role is offered, which is also the repair path for
  // an account locked out by a bad claim.

  function handleRoleChange(nextRole: AdminRole) {
    startTransition(async () => {
      const result = await changeAdminRole(admin.uid, nextRole);
      if (result.ok) {
        toast.success(`Rol ${ROLE_LABELS[nextRole]} olaraq dəyişdirildi.`);
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
        {ADMIN_ROLES.filter((r) => r !== admin.role).map((r) => (
          <DropdownMenuItem key={r} onClick={() => handleRoleChange(r)}>
            {`${ROLE_LABELS[r]} et`}
          </DropdownMenuItem>
        ))}
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
