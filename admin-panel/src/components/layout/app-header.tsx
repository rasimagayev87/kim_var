import { Badge } from "@/components/ui/badge";
import { LogoutButton } from "@/components/auth/logout-button";
import type { AdminSession } from "@/lib/auth/session";

export function AppHeader({ admin }: { admin: AdminSession }) {
  return (
    <header className="flex h-14 items-center justify-between border-b bg-background px-5">
      <div className="flex items-center gap-2 md:hidden">
        <span className="text-sm font-semibold tracking-tight">Kim Var Admin</span>
      </div>
      <div className="hidden items-center gap-2 text-sm text-muted-foreground md:flex">
        <span className="font-medium text-foreground">{admin.email}</span>
        <Badge variant={admin.role === "admin" ? "default" : "secondary"} className="capitalize">
          {admin.role}
        </Badge>
      </div>
      <div className="w-32">
        <LogoutButton />
      </div>
    </header>
  );
}
