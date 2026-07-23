"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { addAdmin } from "@/lib/actions/admins";
import type { AdminRole } from "@/lib/auth/session";

const ERROR_MESSAGES: Record<string, string> = {
  "user-not-found": "Bu email ünvanı ilə Meevima hesabı tapılmadı. Əvvəlcə həmin şəxs adi istifadəçi kimi qeydiyyatdan keçməlidir.",
  "invalid-input": "Email boş ola bilməz.",
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
};

export function AddAdminDialog() {
  const [open, setOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<AdminRole>("moderator");
  const [pending, startTransition] = useTransition();

  function handleSubmit() {
    startTransition(async () => {
      const result = await addAdmin(email, role);
      if (result.ok) {
        toast.success(`${email} — ${role} olaraq əlavə edildi.`);
        setEmail("");
        setRole("moderator");
        setOpen(false);
      } else {
        toast.error(ERROR_MESSAGES[result.error ?? ""] ?? "Əlavə edilmədi.");
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Button onClick={() => setOpen(true)}>Yeni admin/moderator əlavə et</Button>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Yeni admin/moderator əlavə et</DialogTitle>
          <DialogDescription>
            Email mövcud bir Meevima hesabına aid olmalıdır — həmin hesaba admin panelə giriş rolu təyin ediləcək.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="admin-email">Email</Label>
            <Input
              id="admin-email"
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="istifadeci@example.com"
            />
          </div>
          <div className="space-y-2">
            <Label>Rol</Label>
            <Select value={role} onValueChange={(value) => setRole(value as AdminRole)}>
              <SelectTrigger className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="moderator">Moderator</SelectItem>
                <SelectItem value="admin">Admin</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>
            Ləğv et
          </Button>
          <Button onClick={handleSubmit} disabled={pending || !email.trim()}>
            {pending ? "Əlavə edilir..." : "Əlavə et"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
