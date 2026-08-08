"use client";

import {
  LayoutGrid,
  Users,
  Store,
  Tag,
  Flag,
  Bell,
  ScrollText,
  ShieldCheck,
  CreditCard,
  Sparkles,
  BarChart3,
  KeyRound,
  Settings,
  MapPinned,
} from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { hasPermission, type Permission } from "@/lib/auth/permissions";
import type { AdminRole } from "@/lib/auth/session";
import { ComingSoonBadge } from "@/components/dashboard/ComingSoon";

// Same hrefs/permissions as the previous nav-items.ts (moderateVenues,
// manageFeedback, etc.) — only the visual treatment changed. A
// moderator still can't see İstifadəçilər/Bildirişlər/Admin
// idarəetməsi here, same as before.
const EXISTING_NAV: { href: string; label: string; icon: typeof LayoutGrid; permission?: Permission }[] = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutGrid },
  { href: "/users", label: "İstifadəçilər", icon: Users, permission: "manageUsers" },
  { href: "/venues", label: "Məkanlar", icon: Store, permission: "moderateVenues" },
  { href: "/offers", label: "Təkliflər", icon: Tag, permission: "moderateOffers" },
  { href: "/feedback", label: "Şikayətlər", icon: Flag, permission: "manageFeedback" },
  { href: "/notifications", label: "Bildirişlər", icon: Bell, permission: "broadcastNotifications" },
  { href: "/logs", label: "Loglar", icon: ScrollText },
  { href: "/admins", label: "Admin idarəetməsi", icon: ShieldCheck, permission: "manageAdmins" },
];

// New — no backend behind these yet, "Tezliklə" until each is wired up.
const PLANNED_NAV = [
  { href: "/map", label: "Xəritə", icon: MapPinned, badge: "Tezliklə" },
  { href: "/subscriptions", label: "Abunəliklər", icon: CreditCard, badge: "Tezliklə" },
  { href: "/ai-center", label: "AI Mərkəzi", icon: Sparkles, badge: "Tezliklə" },
  { href: "/analytics", label: "Analytics", icon: BarChart3, badge: "Tezliklə" },
  { href: "/roles", label: "Rollar və İcazələr", icon: KeyRound, badge: "Tezliklə" },
];

export function Sidebar({ role }: { role: AdminRole }) {
  const pathname = usePathname();
  const visibleExisting = EXISTING_NAV.filter((item) => !item.permission || hasPermission(role, item.permission));

  return (
    <aside className="hidden lg:flex lg:w-64 lg:flex-col lg:fixed lg:inset-y-0 border-r border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark">
      <div className="flex items-center gap-2 px-5 h-16 border-b border-dash-border dark:border-dash-border-dark">
        <Image src="/peakpin-logo.png" alt="PeakPin" width={28} height={28} className="rounded-lg" priority />
        <span className="font-semibold text-ink dark:text-ink-dark tracking-tight">
          PeakPin
        </span>
        <span className="ml-auto text-[10px] font-mono uppercase tracking-wider text-ink-muted dark:text-ink-muted-dark px-1.5 py-0.5 rounded border border-dash-border dark:border-dash-border-dark">
          Admin
        </span>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-0.5">
        {visibleExisting.map((item) => (
          <NavItem key={item.href} item={item} active={pathname === item.href || pathname.startsWith(`${item.href}/`)} />
        ))}

        <div className="pt-4 mt-4 border-t border-dash-border dark:border-dash-border-dark">
          <p className="px-3 pb-2 text-[11px] font-medium uppercase tracking-wider text-ink-muted dark:text-ink-muted-dark">
            Planlaşdırılan
          </p>
          {PLANNED_NAV.map((item) => (
            <NavItem key={item.href} item={item} active={pathname === item.href} />
          ))}
          <NavItem item={{ href: "/settings", label: "Tənzimləmələr", icon: Settings }} active={pathname === "/settings"} />
        </div>
      </nav>

      <SidebarSystemStatus />

      <div className="px-5 py-3 border-t border-dash-border dark:border-dash-border-dark text-[11px] font-mono text-ink-muted dark:text-ink-muted-dark">
        PeakPin v1.0.0
      </div>
    </aside>
  );
}

const STATUS_ROWS = [
  { key: "server", label: "Server" },
  { key: "database", label: "Database" },
  { key: "storage", label: "Storage" },
  { key: "api", label: "API" },
] as const;

function SidebarSystemStatus() {
  return (
    <div className="px-5 py-3 border-t border-dash-border dark:border-dash-border-dark">
      <div className="flex items-center gap-2 mb-2">
        <p className="text-[11px] font-medium uppercase tracking-wider text-ink-muted dark:text-ink-muted-dark">
          Sistem Statusu
        </p>
        <ComingSoonBadge />
      </div>
      <ul className="space-y-1">
        {STATUS_ROWS.map((row) => (
          <li key={row.key} className="flex items-center justify-between text-[11px]">
            <span className="text-ink-muted dark:text-ink-muted-dark">{row.label}</span>
            <span className="flex items-center gap-1.5 text-ink-muted dark:text-ink-muted-dark">
              <span className="w-1.5 h-1.5 rounded-full bg-ink-muted dark:bg-ink-muted-dark" />
              —
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function NavItem({
  item,
  active,
}: {
  item: {
    href: string;
    label: string;
    icon: typeof LayoutGrid;
    badge?: string;
    count?: number;
  };
  active: boolean;
}) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      className={cn(
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors",
        active
          ? "bg-cyan-soft text-ink dark:bg-cyan/10 dark:text-cyan font-medium"
          : "text-ink-muted dark:text-ink-muted-dark hover:bg-canvas dark:hover:bg-surface-raised-dark hover:text-ink dark:hover:text-ink-dark"
      )}
    >
      <Icon className="w-[18px] h-[18px] shrink-0" strokeWidth={1.75} />
      <span className="flex-1">{item.label}</span>
      {item.count !== undefined && item.count > 0 && (
        <span className="text-[10px] font-mono px-1.5 py-0.5 rounded-pill bg-cyan text-white">
          {item.count}
        </span>
      )}
      {item.badge && (
        <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-amber-soft text-amber-700 dark:bg-amber/15 dark:text-amber">
          {item.badge}
        </span>
      )}
    </Link>
  );
}
