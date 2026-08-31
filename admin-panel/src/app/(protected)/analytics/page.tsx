import { redirect } from "next/navigation";

import {
  CohortPanel,
  ContentPanel,
  EngagementPanel,
  RegistrationPanel,
  RevenuePanel,
} from "@/components/analytics/panels";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import {
  COHORT_ACTIVE_WINDOW_DAYS,
  getCohortActivity,
  getContentCounts,
  getEngagementMetrics,
  getRegistrationCounts,
  getRegistrationSeries,
  getRevenueSeries,
  getRevenueTotals,
  getSubscriptionsByTier,
  safeAnalyticsQuery,
} from "@/lib/data/analytics";

/**
 * The `analyst` workspace, and the first screen built for that role.
 *
 * THREE GATES, NOT ONE:
 *   `viewAnalytics`          — the page itself (every role has it)
 *   `viewEngagementMetrics`  — DAU/WAU/MAU + cohorts (not finance, not support)
 *   `viewRevenue`            — money (not moderator, not support)
 *
 * Blocks are FETCHED conditionally, not fetched and hidden. A
 * moderator's session never queries `payments` at all; a finance
 * session never queries `users` for activity. Rendering a card behind
 * a role check while the data was already read would be the same
 * mistake as hiding a button — see the dashboard's own note (P0 / H-7).
 *
 * NO PERSONAL DATA. Everything here is a count or a sum. The data
 * module reads no user document, projects only `createdAt` and
 * `amount`, and returns no id — see `lib/data/analytics.ts` and the
 * projection test that keeps it that way. This is not a style
 * preference: `analyst` is defined as the role that sees no personal
 * data, and this is the only screen it has.
 *
 * COST, per page load, for a full-access admin:
 *   17 aggregation queries (billed on index entries, flat as the
 *   collections grow) + two windowed reads: accounts created in the
 *   last 30 days, and completed payments in the last 30 days, one
 *   field each. Nothing scans a whole collection.
 *
 *   If daily volume ever makes those two windows expensive, the fix is
 *   a scheduled roll-up — a Cloud Function writing `analytics/daily/
 *   {date}` once a day, with this page reading 30 small documents. Not
 *   built yet on purpose: it is a second source of truth for numbers
 *   that are currently cheap to compute directly, and it should be
 *   added when the reads justify it, not before.
 */
export default async function AnalyticsPage() {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewAnalytics")) {
    redirect("/unauthorized");
  }

  const canSeeEngagement = hasPermission(admin.role, "viewEngagementMetrics");
  const canSeeRevenue = hasPermission(admin.role, "viewRevenue");

  // Every panel is fetched independently. `safeAnalyticsQuery` turns a
  // rejection into `null` and logs it, so one broken query costs one
  // card rather than the page — see that function for why this is not
  // over-engineering. Permission still decides whether the query runs
  // AT ALL; a `null` here means "permitted but failed", which is a
  // different thing from "not permitted" and is reported differently
  // below.
  const q = safeAnalyticsQuery;
  const [engagement, cohorts, registrations, registrationSeries, content, revenue, revenueSeries, tiers] =
    await Promise.all([
      canSeeEngagement ? q("engagement", getEngagementMetrics) : null,
      canSeeEngagement ? q("cohorts", () => getCohortActivity()) : null,
      q("registrations", getRegistrationCounts),
      q("registrationSeries", () => getRegistrationSeries()),
      q("content", getContentCounts),
      canSeeRevenue ? q("revenue", getRevenueTotals) : null,
      canSeeRevenue ? q("revenueSeries", () => getRevenueSeries()) : null,
      canSeeRevenue ? q("subscriptionTiers", getSubscriptionsByTier) : null,
    ]);

  // "Permitted, but the query failed" — the only case worth surfacing
  // to the reader, because a blank page with no explanation is what
  // sent them to ask what broke.
  const failed = [
    canSeeEngagement && !engagement ? "aktiv istifadəçilər" : null,
    canSeeEngagement && !cohorts ? "qeydiyyat kohortları" : null,
    !registrations ? "qeydiyyat sayları" : null,
    !registrationSeries ? "qeydiyyat qrafiki" : null,
    !content ? "aktiv məzmun" : null,
    canSeeRevenue && !revenue ? "gəlir" : null,
    canSeeRevenue && !revenueSeries ? "gəlir qrafiki" : null,
    canSeeRevenue && !tiers ? "abunə tarifləri" : null,
  ].filter((x): x is string => x !== null);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Analitika</h1>
        <p className="text-sm text-muted-foreground">
          Yalnız aqreqat göstəricilər — say, cəm, faiz. Bu səhifə heç bir fərdi istifadəçi
          sənədini oxumur və ad, e-poçt, uid və ya koordinat göstərmir.
        </p>
      </div>

      {failed.length > 0 ? (
        <div className="rounded-lg border border-amber-500/40 bg-amber-500/10 p-4 text-sm">
          <p className="font-medium">Bəzi bölmələr yüklənmədi</p>
          <p className="mt-1 text-muted-foreground">
            {failed.join(", ")}. Səhifənin qalanı işləyir. Səbəb server loglarındadır — ən çox
            rast gəlinən hal hələ qurulmaqda olan Firestore indeksidir.
          </p>
        </div>
      ) : null}

      {engagement ? <EngagementPanel metrics={engagement} /> : null}
      {registrations && registrationSeries ? (
        <RegistrationPanel counts={registrations} series={registrationSeries} />
      ) : null}
      {content ? <ContentPanel counts={content} /> : null}
      {revenue && revenueSeries && tiers ? (
        <RevenuePanel totals={revenue} series={revenueSeries} tiers={tiers} />
      ) : null}
      {cohorts ? <CohortPanel cohorts={cohorts} windowDays={COHORT_ACTIVE_WINDOW_DAYS} /> : null}

      {!canSeeEngagement || !canSeeRevenue ? (
        <p className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">
          Rolunuz bu səhifənin bəzi bölmələrini görmür
          {!canSeeEngagement ? " (aktivlik göstəriciləri)" : ""}
          {!canSeeEngagement && !canSeeRevenue ? " və" : ""}
          {!canSeeRevenue ? " (gəlir)" : ""}. Həmin məlumat sizin sessiyanız üçün{" "}
          <strong>ümumiyyətlə sorğulanmır</strong>.
        </p>
      ) : null}
    </div>
  );
}
