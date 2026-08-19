"use client";

import { Search, Sun, Moon, Command } from "lucide-react";
import { toast } from "sonner";
import { useTheme } from "@/components/dashboard/ThemeProvider";
import { NotificationBell } from "@/components/dashboard/NotificationBell";
import { LogoutButton } from "@/components/auth/logout-button";
import type { AdminNotificationRow } from "@/lib/data/admin-notifications";
import type { PendingCounts } from "@/lib/pending-sections";
import type { AdminRole } from "@/lib/auth/session";

interface TopbarProps {
  adminEmail: string;
  adminRole: AdminRole;
  notifications: AdminNotificationRow[];
  unreadNotificationsCount: number;
  pendingCounts: PendingCounts;
}

export function Topbar({
  adminEmail,
  adminRole,
  notifications,
  unreadNotificationsCount,
  pendingCounts,
}: TopbarProps) {
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="h-16 border-b border-dash-border dark:border-dash-border-dark bg-surface/80 dark:bg-surface-dark/80 backdrop-blur-sm sticky top-0 z-30 flex items-center gap-4 px-6">
      <div>
        <h1 className="text-sm font-semibold text-ink dark:text-ink-dark leading-none">
          Əməliyyat Mərkəzi
        </h1>
        <p className="text-xs text-ink-muted dark:text-ink-muted-dark mt-0.5">
          PeakPin-in ümumi vəziyyətinə baxış
        </p>
      </div>

      <div className="flex-1 max-w-md ml-6">
        <label className="relative block">
          <Search className="w-4 h-4 text-ink-muted dark:text-ink-muted-dark absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Axtar..."
            onFocus={(e) => {
              e.currentTarget.blur();
              toast("Tezliklə əlavə olunacaq");
            }}
            className="w-full h-9 pl-9 pr-14 rounded-lg bg-canvas dark:bg-surface-raised-dark border border-dash-border dark:border-dash-border-dark text-sm text-ink dark:text-ink-dark placeholder:text-ink-muted dark:placeholder:text-ink-muted-dark focus:outline-none focus:ring-2 focus:ring-cyan/40 focus:border-cyan transition"
          />
          <span className="absolute right-2.5 top-1/2 -translate-y-1/2 flex items-center gap-0.5 text-[11px] font-mono text-ink-muted dark:text-ink-muted-dark border border-dash-border dark:border-dash-border-dark rounded px-1.5 py-0.5">
            <Command className="w-3 h-3" /> K
          </span>
        </label>
      </div>

      <div className="flex items-center gap-2 ml-auto">
        <button
          onClick={toggleTheme}
          className="w-9 h-9 rounded-lg flex items-center justify-center text-ink-muted dark:text-ink-muted-dark hover:bg-canvas dark:hover:bg-surface-raised-dark transition"
          aria-label="Tema dəyiş"
        >
          {theme === "dark" ? <Sun className="w-[18px] h-[18px]" /> : <Moon className="w-[18px] h-[18px]" />}
        </button>

        <NotificationBell
          initialRows={notifications}
          initialUnreadCount={unreadNotificationsCount}
          pendingCounts={pendingCounts}
        />

        <div className="w-px h-6 bg-dash-border dark:bg-dash-border-dark mx-1" />

        <div className="flex items-center gap-2.5 pl-1 pr-2">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple to-pink flex items-center justify-center text-white text-xs font-semibold overflow-hidden shrink-0">
            {adminEmail.charAt(0).toUpperCase()}
          </div>
          <div className="hidden sm:block leading-tight">
            <p className="text-xs font-medium text-ink dark:text-ink-dark">{adminEmail}</p>
            <p className="text-[11px] text-ink-muted dark:text-ink-muted-dark capitalize">{adminRole}</p>
          </div>
        </div>

        <div className="w-24 shrink-0">
          <LogoutButton />
        </div>
      </div>
    </header>
  );
}
