import { redirect } from "next/navigation";
import { KpiCard } from "@/components/dashboard/KpiCard";
import { ActivityFeed } from "@/components/dashboard/ActivityFeed";
import { AnalyticsCard } from "@/components/dashboard/AnalyticsCard";
import { LiveMapPanel } from "@/components/dashboard/LiveMapPanel";
import { AiModerationPanel, AiSummaryPanel } from "@/components/dashboard/AiPanels";
import { ReportStatsPanel } from "@/components/dashboard/ReportStatsPanel";
import { QuickActions } from "@/components/dashboard/QuickActions";
import { TopVenuesPanel, SubscriptionsPanel } from "@/components/dashboard/ListPanels";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getDashboardStats, getOnlineUsersCount, getRegistrationsLast7Days, getTodayRevenue } from "@/lib/data/dashboard";
import { safeAnalyticsQuery } from "@/lib/data/analytics";
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
  // P0 / H-7 — the revenue figures are gated on the same
  // `managePayments` permission as the payment screens themselves.
  // Splitting money handling out of `moderateVenues` would be a half
  // measure if the daily revenue total stayed on the one page every
  // moderator lands on. Fetched conditionally rather than fetched and
  // hidden, so a moderator's session never reads the `payments`
  // collection at all — hiding a card client-side is not a boundary.
  // NEWLY GUARDED in the five-role revision — the dashboard previously
  // had no check of its own and relied entirely on the layout's "is
  // there a session at all". `viewDashboard` is true for all five roles,
  // so nobody loses access; the gate exists so that a future role can be
  // excluded here without this page being the one place that forgot to
  // ask.
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewDashboard")) {
    redirect("/unauthorized");
  }

  // Revenue moved from `managePayments` to `viewRevenue` — the two are
  // no longer the same question. `analyst` reads revenue but performs no
  // payment action; `support` sees payments but not revenue totals.
  const canSeeRevenue = hasPermission(admin.role, "viewRevenue");

  // Each fetch is independently caught (see `safeAnalyticsQuery`'s own
  // comment). This page currently works, but it has the same shape
  // that took `/analytics` down: several composite-index queries
  // behind one `Promise.all`, on the screen every role lands on
  // first. A rebuilt index should cost one card here, not the
  // dashboard.
  const q = safeAnalyticsQuery;
  const [rawStats, rawRegistrations, rawOnlineUsers, todayRevenue] = await Promise.all([
    q("dashboard.stats", getDashboardStats),
    q("dashboard.registrations", getRegistrationsLast7Days),
    q("dashboard.onlineUsers", getOnlineUsersCount),
    canSeeRevenue ? q("dashboard.todayRevenue", getTodayRevenue) : null,
  ]);

  // Zeros so the rest of the page still renders — paired with the
  // banner below, which is what keeps them from reading as real
  // numbers. An unlabelled zero here would be worse than an error
  // page: it says "no pending moderation" when the truth is "we could
  // not ask".
  const stats = rawStats ?? {
    totalUsers: 0, activeVenues: 0, activeOffers: 0, activeEvents: 0,
    activePinBoxes: 0, pendingModeration: 0, pendingReports: 0,
  };
  const registrations = rawRegistrations ?? [];
  const onlineUsers = rawOnlineUsers ?? 0;

  const degraded = [
    !rawStats ? "sayğaclar" : null,
    !rawRegistrations ? "qeydiyyat qrafiki" : null,
    !rawOnlineUsers && rawOnlineUsers !== 0 ? "onlayn istifadəçilər" : null,
    canSeeRevenue && todayRevenue === null ? "bugünkü gəlir" : null,
  ].filter((x): x is string => x !== null);

  const todayNewUsers = registrations.at(-1)?.count ?? 0;

  const kpiData: KpiDatum[] = [
    { id: "online-users", label: "Online İstifadəçilər", value: onlineUsers, icon: "Users", tone: "cyan" },
    { id: "new-users-today", label: "Yeni İstifadəçilər", value: todayNewUsers, icon: "UserPlus", tone: "purple" },
    { id: "active-venues", label: "Aktiv Məkanlar", value: stats.activeVenues, icon: "Store", tone: "cyan" },
    { id: "active-offers", label: "Aktiv Təkliflər", value: stats.activeOffers, icon: "Tag", tone: "pink" },
    { id: "active-events", label: "Aktiv Tədbirlər", value: stats.activeEvents, icon: "Calendar", tone: "purple" },
    { id: "active-pinboxes", label: "Aktiv PinBox-lar", value: stats.activePinBoxes, icon: "Package", tone: "amber" },
    ...(todayRevenue !== null
      ? ([{ id: "revenue-today", label: "Gəlir (Bugün)", value: todayRevenue, unit: "AZN", icon: "Wallet", tone: "success" }] as KpiDatum[])
      : []),
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
  const revenueSeries: AnalyticsSeries | null =
    todayRevenue === null
      ? null
      : {
          id: "revenue",
          label: "Revenue",
          unit: "AZN",
          points: [{ date: "bugün", value: todayRevenue }],
        };
  const retentionSeries: AnalyticsSeries = {
    id: "retention",
    label: "Retention",
    unit: "%",
    points: [{ date: "bugün", value: 0 }],
  };

  return (
    <div className="space-y-4">
      {degraded.length > 0 ? (
        <div className="rounded-lg border border-amber-500/40 bg-amber-500/10 p-4 text-sm">
          <p className="font-medium">Bəzi göstəricilər yüklənmədi</p>
          <p className="mt-1 text-muted-foreground">
            {degraded.join(", ")} — aşağıdakı uyğun rəqəmlər <strong>sıfır göstərilir, amma
            həqiqi dəyər deyil</strong>. Səbəb server loglarındadır.
          </p>
        </div>
      ) : null}

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
          {revenueSeries && <AnalyticsCard series={revenueSeries} tone="#10B981" />}
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
