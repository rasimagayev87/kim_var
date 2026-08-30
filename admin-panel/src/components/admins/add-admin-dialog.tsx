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
  "email-taken": "Bu email ünvanı artıq mövcud bir hesaba aiddir (mobil istifadəçi ola bilər) — admin hesabları tam ayrı email istifadə etməlidir.",
  "invalid-input": "Email boş, parol isə ən azı 6 simvol olmalıdır.",
  forbidden: "Bu əməliyyat üçün icazəniz yoxdur.",
  "invalid-role": "Naməlum rol. Yalnız 'admin' və 'moderator' qəbul edilir.",
};

export function AddAdminDialog() {
  const [open, setOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<AdminRole>("moderator");
  const [pending, startTransition] = useTransition();

  function handleSubmit() {
    startTransition(async () => {
      const result = await addAdmin(email, password, role);
      if (result.ok) {
        toast.success(`${email} — ${role} olaraq əlavə edildi.`);
        setEmail("");
        setPassword("");
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
            Tam yeni, admin-only hesab yaradılacaq — mobil tətbiqdə istifadə olunan heç bir email ilə üst-üstə düşə bilməz.
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
              placeholder="admin@peakpin.app"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="admin-password">Parol</Label>
            <Input
              id="admin-password"
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Ən azı 6 simvol"
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
          <Button onClick={handleSubmit} disabled={pending || !email.trim() || password.length < 6}>
            {pending ? "Əlavə edilir..." : "Əlavə et"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
