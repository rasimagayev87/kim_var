import "server-only";

import { AggregateField, Timestamp } from "firebase-admin/firestore";

import { getAdminDb } from "@/lib/firebase/admin";
import { categoriesAtFee, SUBSCRIPTION_FEE_TIERS } from "@/lib/venue-fees";

/**
 * Aggregates for `/analytics`. Nothing here returns, or can return, a
 * person.
 *
 * `analyst` is defined as the role that sees no personal data, and this
 * is the only screen built for that role — so the constraint has to
 * hold in the query layer, not in the rendering. Every function below
 * either uses a Firestore aggregation (`count()` / `sum()`, which
 * return a number and never a document) or a `.select()` projection
 * limited to [ANALYTICS_FIELD_PROJECTIONS]. No function reads a user
 * document, and none returns an id.
 *
 * The projection list is exported and asserted against a denylist in
 * `tests/rules/analytics-projections.test.ts`. That test cannot prove
 * runtime behaviour — what it proves is that the fields this module
 * declares it reads contain no identity, and that adding one later
 * breaks the build's tests rather than quietly shipping.
 *
 * COST. Aggregation queries are billed on index entries scanned, not
 * documents returned, so the counters stay flat as the collections
 * grow. The two time series do read documents — but only those inside
 * a 30-day window, and only one field each. If daily volume ever makes
 * that matter, the fix is a scheduled roll-up (`analytics/daily/{date}`)
 * rather than a wider query here; see the page's own note.
 */

/** Every field this module projects. Deliberately tiny. */
export const ANALYTICS_FIELD_PROJECTIONS: readonly string[] = ["createdAt", "amount"];

/** Fields that must never appear above. Identity, contact, location. */
export const PII_FIELD_DENYLIST: readonly string[] = [
  "uid", "userId", "ownerId", "buyerId", "senderId", "email", "phoneNumber",
  "firstName", "lastName", "username", "name", "photoUrl", "bio", "birthDate",
  "lat", "lng", "position", "address", "fcmTokens", "blockedUsers", "comment",
  "message", "reason",
];

export interface EngagementMetrics {
  dau: number;
  wau: number;
  mau: number;
}

export interface RegistrationCounts {
  today: number;
  last7Days: number;
  last30Days: number;
}

export interface ContentCounts {
  activeVenues: number;
  activeOffers: number;
  activePinBoxes: number;
  activeEvents: number;
}

export interface RevenueTotals {
  today: number;
  last7Days: number;
  last30Days: number;
}

export interface SubscriptionTierBreakdown {
  /** Monthly price in AZN. */
  feeAzn: number;
  /** How many approved venues sit in this price tier. */
  venues: number;
  /** Categories charged this much — for the tooltip, no venue data. */
  categoryCount: number;
}

export interface SeriesPoint {
  /** ISO date, yyyy-mm-dd, local server time. */
  date: string;
  value: number;
}

export interface CohortActivity {
  /** yyyy-mm — the month these accounts registered. */
  month: string;
  /**
   * `null` when the true count is below
   * [COHORT_MIN_REPORTABLE_COUNT] — the page renders "<5". See
   * [MIN_REPORTABLE] for why a small cohort is not a statistic.
   */
  registered: number | null;
  /** Same suppression as [registered]. */
  stillActive: number | null;
  /** True when either figure was suppressed. */
  suppressed: boolean;
}

function startOfToday(): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

function daysAgo(n: number): Date {
  const t = startOfToday();
  return new Date(t.getFullYear(), t.getMonth(), t.getDate() - n);
}

async function countWhere(
  collection: string,
  build: (q: FirebaseFirestore.Query) => FirebaseFirestore.Query,
): Promise<number> {
  const snap = await build(getAdminDb().collection(collection)).count().get();
  return snap.data().count;
}

/**
 * DAU / WAU / MAU from `lastSeen`.
 *
 * Three aggregation queries, three reads, independent of user count.
 * `lastSeen` is written by the Flutter client's presence provider; a
 * force-quit can leave it stale, which is the same caveat
 * `isRecentlyOnlineServer` exists for on the discovery side — so these
 * are "seen recently", not "currently online", and the page says so.
 */
export async function getEngagementMetrics(): Promise<EngagementMetrics> {
  const [dau, wau, mau] = await Promise.all([
    countWhere("users", (q) => q.where("lastSeen", ">=", Timestamp.fromDate(daysAgo(1)))),
    countWhere("users", (q) => q.where("lastSeen", ">=", Timestamp.fromDate(daysAgo(7)))),
    countWhere("users", (q) => q.where("lastSeen", ">=", Timestamp.fromDate(daysAgo(30)))),
  ]);
  return { dau, wau, mau };
}

export async function getRegistrationCounts(): Promise<RegistrationCounts> {
  const [today, last7Days, last30Days] = await Promise.all([
    countWhere("users", (q) => q.where("createdAt", ">=", startOfToday())),
    countWhere("users", (q) => q.where("createdAt", ">=", daysAgo(7))),
    countWhere("users", (q) => q.where("createdAt", ">=", daysAgo(30))),
  ]);
  return { today, last7Days, last30Days };
}

export async function getContentCounts(): Promise<ContentCounts> {
  const [activeVenues, activeOffers, activePinBoxes, activeEvents] = await Promise.all([
    countWhere("venues", (q) => q.where("status", "==", "approved")),
    countWhere("offers", (q) => q.where("status", "==", "approved")),
    countWhere("pinboxes", (q) => q.where("status", "==", "active")),
    countWhere("venueEvents", (q) => q.where("status", "in", ["upcoming", "live"])),
  ]);
  return { activeVenues, activeOffers, activePinBoxes, activeEvents };
}

async function sumCompletedSince(since: Date): Promise<number> {
  const snap = await getAdminDb()
    .collection("payments")
    .where("status", "==", "completed")
    .where("createdAt", ">=", since)
    .orderBy("createdAt", "desc")
    .aggregate({ total: AggregateField.sum("amount") })
    .get();
  return snap.data().total ?? 0;
}

/**
 * Completed revenue by window.
 *
 * `sum()` aggregation rather than fetching amounts and adding them up:
 * one read each instead of one per payment, and the figure stays cheap
 * as volume grows.
 *
 * NEEDS ITS OWN INDEX: `payments (status, createdAt, amount)`. A sum
 * aggregation requires the SUMMED field in the index, not just the
 * filtered ones — so the existing `(status, createdAt)` index that
 * `listPayments` and the dashboard use is not enough. This was
 * originally written believing it was, which took `/analytics` down
 * with a FAILED_PRECONDITION on first load. `.select("amount")` has no
 * such requirement, which is why the dashboard's own revenue query and
 * [getRevenueSeries] below kept working.
 */
export async function getRevenueTotals(): Promise<RevenueTotals> {
  const [today, last7Days, last30Days] = await Promise.all([
    sumCompletedSince(startOfToday()),
    sumCompletedSince(daysAgo(7)),
    sumCompletedSince(daysAgo(30)),
  ]);
  return { today, last7Days, last30Days };
}

/**
 * Approved venues grouped by monthly price.
 *
 * By TIER, not by category: there are ~36 categories but only four
 * prices, so this is four aggregation queries instead of thirty-six,
 * and it stays four as categories are added. `venue-fees.ts` owns the
 * grouping and a test asserts no tier exceeds Firestore's 30-value
 * `in` limit.
 */
export async function getSubscriptionsByTier(): Promise<SubscriptionTierBreakdown[]> {
  return Promise.all(
    SUBSCRIPTION_FEE_TIERS.map(async (feeAzn) => {
      const categories = categoriesAtFee(feeAzn);
      const venues = await countWhere("venues", (q) =>
        q.where("status", "==", "approved").where("category", "in", categories),
      );
      return { feeAzn, venues, categoryCount: categories.length };
    }),
  );
}

function emptySeries(days: number): { points: SeriesPoint[]; starts: Date[] } {
  const points: SeriesPoint[] = [];
  const starts: Date[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const start = daysAgo(i);
    starts.push(start);
    points.push({ date: start.toISOString().slice(0, 10), value: 0 });
  }
  return { points, starts };
}

function bucketIndex(starts: Date[], at: Date): number {
  for (let i = starts.length - 1; i >= 0; i--) {
    if (at >= starts[i]) return i;
  }
  return -1;
}

/**
 * Daily registrations over [days].
 *
 * Firestore has no server-side GROUP BY, so this reads one field per
 * account created in the window and buckets in memory — the same
 * approach and the same caveat as the dashboard's 7-day chart.
 */
export async function getRegistrationSeries(days = 30): Promise<SeriesPoint[]> {
  const { points, starts } = emptySeries(days);
  const snap = await getAdminDb()
    .collection("users")
    .where("createdAt", ">=", starts[0])
    .select("createdAt")
    .get();

  for (const doc of snap.docs) {
    const at = (doc.get("createdAt") as Timestamp | undefined)?.toDate();
    if (!at) continue;
    const i = bucketIndex(starts, at);
    if (i >= 0) points[i].value += 1;
  }
  return points;
}

/** Daily completed revenue over [days]. Same shape and caveat as above. */
export async function getRevenueSeries(days = 30): Promise<SeriesPoint[]> {
  const { points, starts } = emptySeries(days);
  const snap = await getAdminDb()
    .collection("payments")
    .where("status", "==", "completed")
    .where("createdAt", ">=", starts[0])
    .orderBy("createdAt", "desc")
    .select("amount", "createdAt")
    .get();

  for (const doc of snap.docs) {
    const at = (doc.get("createdAt") as Timestamp | undefined)?.toDate();
    if (!at) continue;
    const i = bucketIndex(starts, at);
    if (i >= 0) points[i].value += (doc.get("amount") as number | undefined) ?? 0;
  }
  return points;
}

/** How many days of inactivity still counts as "active" for the cohorts. */
export const COHORT_ACTIVE_WINDOW_DAYS = 7;

/**
 * k-anonymity floor for the cohort table — the same value and the same
 * reasoning as `VENUE_AUDIENCE_MIN_REPORTABLE_COUNT` in
 * `functions/src/geo.ts` (P0 / H-2).
 *
 * A cohort of one is not a statistic. "1 registered in 2026-03, 1
 * still active" describes a person, and this screen is the one built
 * for the role defined as seeing no personal data — a role that may
 * well know who joined that month. The floor was missing when the page
 * was first built; it was found reviewing the page's own attack
 * surface, which is exactly the kind of finding that gets deferred
 * into a backlog and never returned to.
 *
 * Suppression is all-or-nothing per row: hiding only `stillActive`
 * while showing `registered: 1` would leak the same fact.
 */
export const COHORT_MIN_REPORTABLE_COUNT = 5;

/**
 * NOT retention, and the page must not call it that.
 *
 * True retention needs to know whether a person came back — first
 * session, later sessions, a cohort followed over time. This schema
 * stores `createdAt` and a single `lastSeen`, so the only honest
 * question it can answer is: of the accounts that registered in month
 * M, how many have been seen in the last [COHORT_ACTIVE_WINDOW_DAYS]
 * days?
 *
 * That is a real and useful number — it is roughly "are the people who
 * joined in March still here" — but it is a snapshot, not a curve. It
 * cannot distinguish someone who used the app daily and stopped
 * yesterday from someone who opened it once yesterday. It also only
 * ever moves in one direction as the window slides. The page carries
 * that sentence next to the number so nobody reads it as a retention
 * curve.
 *
 * Two aggregation queries per month, and the `(createdAt, lastSeen)`
 * composite index in `firestore.indexes.json` is what makes the second
 * one possible. Rows below [COHORT_MIN_REPORTABLE_COUNT] are
 * suppressed before they leave this function — the true number never
 * reaches the component.
 */
export async function getCohortActivity(months = 6): Promise<CohortActivity[]> {
  const now = new Date();
  const activeSince = Timestamp.fromDate(daysAgo(COHORT_ACTIVE_WINDOW_DAYS));

  const cohorts: Array<{ month: string; start: Date; end: Date }> = [];
  for (let i = months - 1; i >= 0; i--) {
    const start = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const end = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
    cohorts.push({ month: start.toISOString().slice(0, 7), start, end });
  }

  return Promise.all(
    cohorts.map(async ({ month, start, end }) => {
      const [registered, stillActive] = await Promise.all([
        countWhere("users", (q) => q.where("createdAt", ">=", start).where("createdAt", "<", end)),
        countWhere("users", (q) =>
          q
            .where("createdAt", ">=", start)
            .where("createdAt", "<", end)
            .where("lastSeen", ">=", activeSince),
        ),
      ]);
      const suppressed =
        registered > 0 && registered < COHORT_MIN_REPORTABLE_COUNT;
      return suppressed
        ? { month, registered: null, stillActive: null, suppressed: true }
        : { month, registered, stillActive, suppressed: false };
    }),
  );
}

/**
 * Runs one panel's query, turning a failure into `null` instead of a
 * rejected promise.
 *
 * The page fans out ~30 queries. Under `Promise.all` a single
 * rejection takes the whole page down with a 500 — which is exactly
 * what a missing index did here, and exactly what `pending-counts.ts`
 * already had to learn once ("this ran production down once already
 * before this try/catch existed"). A page made of independent
 * aggregates should degrade panel by panel: a missing index, a
 * still-building one, or a Firestore hiccup should cost one card, not
 * the screen.
 *
 * Errors are logged, never swallowed silently — a panel that quietly
 * renders nothing is its own kind of bug.
 */
export async function safeAnalyticsQuery<T>(label: string, run: () => Promise<T>): Promise<T | null> {
  try {
    return await run();
  } catch (error) {
    console.error(`analytics: "${label}" query failed — panel degraded`, error);
    return null;
  }
}
