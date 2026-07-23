"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { hasPermission } from "@/lib/auth/permissions";
import type { AdminRole } from "@/lib/auth/session";
import { cn } from "@/lib/utils";
import { NAV_ITEMS } from "./nav-items";

export function AppSidebar({ role }: { role: AdminRole }) {
  const pathname = usePathname();

  return (
    <aside className="hidden w-60 shrink-0 border-r bg-sidebar md:flex md:flex-col">
      <div className="flex h-14 items-center border-b px-5">
        <span className="text-sm font-semibold tracking-tight">Kim Var Admin</span>
      </div>
      <nav className="flex-1 space-y-1 p-3">
        {NAV_ITEMS.filter((item) => !item.permission || hasPermission(role, item.permission)).map(
          (item) => {
            const Icon = item.icon;
            // `startsWith` so a detail sub-route (e.g. /users/abc123)
            // still highlights its parent nav item, not just the exact
            // list page.
            const active = pathname === item.href || pathname.startsWith(`${item.href}/`);

            if (item.comingSoon) {
              return (
                <div
                  key={item.href}
                  className="flex cursor-not-allowed items-center justify-between rounded-md px-3 py-2 text-sm text-muted-foreground/60"
                >
                  <span className="flex items-center gap-2">
                    <Icon className="size-4" />
                    {item.label}
                  </span>
                  <Badge variant="outline" className="text-[10px] font-normal text-muted-foreground/70">
                    tezliklə
                  </Badge>
                </div>
              );
            }

            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                  active
                    ? "bg-primary text-primary-foreground"
                    : "text-sidebar-foreground hover:bg-sidebar-accent",
                )}
              >
                <Icon className="size-4" />
                {item.label}
              </Link>
            );
          },
        )}
      </nav>
    </aside>
  );
}
