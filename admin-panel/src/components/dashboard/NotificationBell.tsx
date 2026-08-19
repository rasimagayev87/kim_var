"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { Bell } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { markAdminNotificationRead, markAllAdminNotificationsRead } from "@/lib/actions/admin-notifications";
import type { AdminNotificationRow } from "@/lib/data/admin-notifications";
import { PENDING_SECTION_META, type PendingCounts } from "@/lib/pending-sections";

const TYPE_LABELS: Record<string, string> = {
  "report.user": "İstifadəçi şikayəti",
  "report.event": "Tədbir şikayəti",
};

/** `/users/{id}` has a real detail page; event reports don't have a
 * per-report route yet, so they land on the list page instead — see
 * `src/app/(protected)/event-reports/page.tsx`. */
function targetHref(row: AdminNotificationRow): string {
  if (row.targetType === "user") return `/users/${row.targetId}`;
  if (row.targetType === "event") return "/event-reports";
  return "#";
}

function formatRelativeTime(iso: string | null): string {
  if (!iso) return "";
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return "indicə";
  if (minutes < 60) return `${minutes} dəq əvvəl`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} saat əvvəl`;
  const days = Math.floor(hours / 24);
  return `${days} gün əvvəl`;
}

/** Bell dropdown — a lightweight in-panel notification inbox, not
 * real-time (initial data comes from the server-rendered layout, see
 * `ProtectedLayout`); refreshes on next navigation/reload like the
 * rest of this admin panel, no client-side Firestore listener. */
export function NotificationBell({
  initialRows,
  initialUnreadCount,
  pendingCounts,
}: {
  initialRows: AdminNotificationRow[];
  initialUnreadCount: number;
  pendingCounts: PendingCounts;
}) {
  const [rows, setRows] = useState(initialRows);
  const [unreadCount, setUnreadCount] = useState(initialUnreadCount);
  const [, startTransition] = useTransition();

  const pendingSections = PENDING_SECTION_META.map((meta) => ({
    ...meta,
    count: pendingCounts[meta.key],
  })).filter((section) => section.count > 0);
  const totalPending = pendingSections.reduce((sum, section) => sum + section.count, 0);

  function handleItemClick(id: string) {
    const row = rows.find((r) => r.id === id);
    if (!row || row.read) return;
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, read: true } : r)));
    setUnreadCount((count) => Math.max(0, count - 1));
    startTransition(() => {
      markAdminNotificationRead(id);
    });
  }

  function handleMarkAllRead() {
    setRows((prev) => prev.map((r) => ({ ...r, read: true })));
    setUnreadCount(0);
    startTransition(() => {
      markAllAdminNotificationsRead();
    });
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        render={
          <Button
            variant="ghost"
            size="icon-lg"
            className="relative text-ink-muted dark:text-ink-muted-dark hover:bg-canvas dark:hover:bg-surface-raised-dark"
            aria-label="Bildirişlər"
          >
            <Bell className="w-[18px] h-[18px]" />
            {totalPending > 0 && (
              <span className="absolute top-1 right-1 min-w-[16px] h-4 px-1 rounded-full bg-cyan text-white text-[10px] font-mono leading-4 text-center">
                {totalPending > 9 ? "9+" : totalPending}
              </span>
            )}
            {unreadCount > 0 && (
              <span className="absolute top-1.5 left-1.5 size-2 rounded-full bg-pink" aria-hidden />
            )}
          </Button>
        }
      />
      <DropdownMenuContent align="end" className="w-80">
        {pendingSections.length > 0 && (
          <>
            <DropdownMenuGroup className="flex items-center justify-between px-2 py-1.5">
              <DropdownMenuLabel className="p-0">Gözləyən təsdiqlər</DropdownMenuLabel>
            </DropdownMenuGroup>
            {pendingSections.map((section) => (
              <DropdownMenuItem
                key={section.key}
                render={<Link href={section.href} />}
                className="flex items-center justify-between"
              >
                <span className="text-xs">{section.label}</span>
                <span className="text-[10px] font-mono px-1.5 py-0.5 rounded-pill bg-cyan text-white">
                  {section.count}
                </span>
              </DropdownMenuItem>
            ))}
            <DropdownMenuSeparator />
          </>
        )}
        <DropdownMenuGroup className="flex items-center justify-between px-2 py-1.5">
          <DropdownMenuLabel className="p-0">Bildirişlər</DropdownMenuLabel>
          {unreadCount > 0 && (
            <button onClick={handleMarkAllRead} className="text-xs text-cyan hover:underline">
              Hamısını oxunmuş et
            </button>
          )}
        </DropdownMenuGroup>
        <DropdownMenuSeparator />
        {rows.length === 0 ? (
          <p className="px-2 py-4 text-center text-sm text-muted-foreground">Bildiriş yoxdur.</p>
        ) : (
          rows.map((row) => (
            <DropdownMenuItem
              key={row.id}
              onClick={() => handleItemClick(row.id)}
              render={<Link href={targetHref(row)} />}
              className="flex flex-col items-start gap-0.5 whitespace-normal"
            >
              <span className="flex w-full items-center gap-1.5 text-xs font-medium">
                {!row.read && <span className="size-1.5 shrink-0 rounded-full bg-cyan" />}
                {TYPE_LABELS[row.type] ?? row.type}
              </span>
              <span className="text-xs text-muted-foreground">{row.message}</span>
              <span className="text-[10px] text-muted-foreground/70">{formatRelativeTime(row.createdAt)}</span>
            </DropdownMenuItem>
          ))
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
