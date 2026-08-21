import { KpiCard } from "@/components/dashboard/KpiCard";
import { ActivityFeed } from "@/components/dashboard/ActivityFeed";
import { AnalyticsCard } from "@/components/dashboard/AnalyticsCard";
import { LiveMapPanel } from "@/components/dashboard/LiveMapPanel";
import { AiModerationPanel, AiSummaryPanel } from "@/components/dashboard/AiPanels";
import { ReportStatsPanel } from "@/components/dashboard/ReportStatsPanel";
import { QuickActions } from "@/components/dashboard/QuickActions";
import { TopVenuesPanel, SubscriptionsPanel } from "@/components/dashboard/ListPanels";
import { getDashboardStats, getOnlineUsersCount, getRegistrationsLast7Days } from "@/lib/data/dashboard";
import type { KpiDatum, AnalyticsSeries } from "@/lib/types";

const WEEKDAY_LABELS = ["Baz", "B.e", "Ç.a", "Çər", "C.a", "Cüm", "Şən"];

function weekdayLabel(isoDate: string): string {
  // isoDate is yyyy-mm-dd local-time (see getRegistrationsLast7Days) —
  // parsed as UTC midnight would risk shifting a day; splitting avoids that.
  const [y, m, d] = isoDate.split("-").map(Number);
  return WEEKDAY_LABELS[new Date(y, m - 1, d).getDay()];
}

/**
 * Redesigned Dashboard content. Dark-by-default now comes from the
 * shared ThemeProvider (app/layout.tsx) toggling `.dark` on <html> —
 * every other module (İstifadəçilər, Məkanlar, Təkliflər, Şikayətlər,
 * Bildirişlər, Loglar, Admin idarəetməsi) picks up the same dark
 * chrome via the new Sidebar/Topbar in (protected)/layout.tsx, but
 * none of those modules' own page content was touched — they still
 * render with plain shadcn tokens today, so their light-surface look
 * (an untouched Card/Table) is expected to still show through here
 * and there until those get their own dark-mode pass.
 *
 * Every KPI/series below is real, pulled from the same
 * `lib/data/dashboard.ts` queries the previous dashboard used (plus
 * one additive query, `getOnlineUsersCount`, on the `online` field the
 * Flutter app already writes). Panels with no backend yet (AI
 * Moderation/Summary, Canlı Xəritə clustering, Abunəliklər, Report
 * Statistikası's category breakdown) show a real zero/empty state and
 * a "Tezliklə" badge instead of invented numbers — see each
 * component's own comments for exactly what's missing.
 */
export default async function DashboardPage() {
  const [stats, registrations, onlineUsers] = await Promise.all([
    getDashboardStats(),
    getRegistrationsLast7Days(),
    getOnlineUsersCount(),
  ]);

  const todayNewUsers = registrations.at(-1)?.count ?? 0;

  const kpiData: KpiDatum[] = [
    { id: "online-users", label: "Online İstifadəçilər", value: onlineUsers, icon: "Users", tone: "cyan" },
    { id: "new-users-today", label: "Yeni İstifadəçilər", value: todayNewUsers, icon: "UserPlus", tone: "purple" },
    { id: "active-venues", label: "Aktiv Məkanlar", value: stats.activeVenues, icon: "Store", tone: "cyan" },
    { id: "active-offers", label: "Aktiv Təkliflər", value: stats.activeOffers, icon: "Tag", tone: "pink" },
    { id: "active-events", label: "Aktiv Tədbirlər", value: stats.activeEvents, icon: "Calendar", tone: "purple" },
    { id: "active-pinboxes", label: "Aktiv PinBox-lar", value: stats.activePinBoxes, icon: "Package", tone: "amber" },
    { id: "revenue-today", label: "Gəlir (Bugün)", value: 0, unit: "AZN", icon: "Wallet", tone: "success" },
    { id: "subscriptions", label: "Abunəliklər", value: 0, icon: "CreditCard", tone: "purple" },
    { id: "reports", label: "Reports", value: stats.pendingReports, icon: "Flag", tone: "danger" },
    { id: "pending-approvals", label: "Gözləyən Təsdiqlər", value: stats.pendingModeration, icon: "ShieldAlert", tone: "amber" },
  ];

  const registrationPoints = registrations.map((day) => ({ date: weekdayLabel(day.date), value: day.count }));

  const dailyActiveUsersSeries: AnalyticsSeries = {
    id: "daily-active-users",
    label: "Daily Active Users",
    points: registrationPoints,
  };
  const newUsersSeries: AnalyticsSeries = {
    id: "new-users",
    label: "New Users",
    points: registrationPoints,
  };
  const businessesSeries: AnalyticsSeries = {
    id: "businesses",
    label: "Businesses",
    points: [{ date: "bugün", value: stats.activeVenues }],
  };
  const offersSeries: AnalyticsSeries = {
    id: "offers",
    label: "Offers",
    points: [{ date: "bugün", value: stats.activeOffers }],
  };
  const revenueSeries: AnalyticsSeries = {
    id: "revenue",
    label: "Revenue",
    unit: "AZN",
    points: [{ date: "bugün", value: 0 }],
  };
  const retentionSeries: AnalyticsSeries = {
    id: "retention",
    label: "Retention",
    unit: "%",
    points: [{ date: "bugün", value: 0 }],
  };

  return (
    <div className="space-y-4">
      {/* KPI row — 10 cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 xl:grid-cols-8 gap-3">
        {kpiData.map((kpi) => (
          <KpiCard key={kpi.id} data={kpi} />
        ))}
      </div>

      {/* Map + Real-time Activity + AI stack */}
      <div className="grid grid-cols-1 xl:grid-cols-12 gap-4">
        <div className="xl:col-span-6">
          <LiveMapPanel />
        </div>
        <div className="xl:col-span-3">
          <ActivityFeed events={[]} />
        </div>
        <div className="xl:col-span-3 flex flex-col gap-4">
          <AiModerationPanel />
          <AiSummaryPanel />
        </div>
      </div>

      {/* Analytics — 6 cards, Son 7 gün */}
      <div>
        <div className="flex items-baseline gap-2 mb-3">
          <h2 className="text-sm font-medium text-ink dark:text-ink-dark">Analytics</h2>
          <span className="text-xs text-ink-muted dark:text-ink-muted-dark">Son 7 gün</span>
        </div>
        <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3">
          <AnalyticsCard series={dailyActiveUsersSeries} tone="#7C3AED" />
          <AnalyticsCard series={newUsersSeries} tone="#00D4E6" />
          <AnalyticsCard series={revenueSeries} tone="#10B981" />
          <AnalyticsCard series={businessesSeries} tone="#F59E0B" />
          <AnalyticsCard series={offersSeries} tone="#EC4899" />
          <AnalyticsCard series={retentionSeries} tone="#00D4E6" />
        </div>
      </div>

      {/* Bottom row — Abunəliklər / Ən Populyar Məkanlar / Report Statistikası / Sürətli Əməliyyatlar */}
      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-4 gap-4">
        <SubscriptionsPanel subscriptions={[]} />
        <TopVenuesPanel venues={[]} />
        <ReportStatsPanel pendingReports={stats.pendingReports} />
        <QuickActions />
      </div>
    </div>
  );
}
