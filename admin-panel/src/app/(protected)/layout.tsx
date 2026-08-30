import { redirect } from "next/navigation";

import { Sidebar } from "@/components/dashboard/Sidebar";
import { Topbar } from "@/components/dashboard/Topbar";
import { getCurrentAdmin } from "@/lib/auth/server";
import { canSeeNotification } from "@/lib/auth/notification-visibility";
import { listRecentAdminNotifications } from "@/lib/data/admin-notifications";
import { getPendingCounts } from "@/lib/data/pending-counts";

/**
 * Shared chrome (sidebar + header) for every real admin-panel screen.
 * Proxy already keeps unauthenticated requests out of this route
 * group, but this re-checks anyway — the same "don't trust Proxy
 * alone" reasoning as everywhere else in the auth layer — and it's
 * also just how the admin identity gets down to Topbar/Sidebar.
 *
 * Previously used AppSidebar/AppHeader (still in
 * components/layout/, now unused) — replaced with the dark-theme
 * Sidebar/Topbar pair so the whole admin panel matches the approved
 * mockup, not just the Dashboard page's own content.
 */
export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const admin = await getCurrentAdmin();
  if (!admin) {
    redirect("/login");
  }

  const [allNotifications, pendingCounts] = await Promise.all([
    listRecentAdminNotifications(),
    getPendingCounts(),
  ]);

  // Filtered per role — see lib/auth/notification-visibility.ts for why
  // this is type-based rather than one on/off permission. The unread
  // count is derived from the SAME filtered list rather than from
  // `getUnreadAdminNotificationsCount()`: a badge counting messages the
  // viewer cannot open is both wrong and a small leak of its own (it
  // reveals how much moderation traffic exists).
  const notifications = allNotifications.filter((n) => canSeeNotification(admin.role, n.type));
  const unreadNotificationsCount = notifications.filter((n) => !n.read).length;

  return (
    <div className="min-h-screen bg-canvas dark:bg-canvas-dark">
      <Sidebar role={admin.role} pendingCounts={pendingCounts} />
      <div className="flex flex-1 flex-col lg:pl-64">
        <Topbar
          adminEmail={admin.email}
          adminRole={admin.role}
          notifications={notifications}
          unreadNotificationsCount={unreadNotificationsCount}
          pendingCounts={pendingCounts}
        />
        <main className="flex-1 p-6">{children}</main>
      </div>
    </div>
  );
}
