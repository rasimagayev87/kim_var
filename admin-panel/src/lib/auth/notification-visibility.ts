import type { AdminRole } from "./roles";
import { hasPermission } from "./permissions";

/**
 * Which admin notifications a given role may see.
 *
 * The bell in `Topbar` is rendered by the protected layout, i.e. on
 * EVERY page for EVERY role. Its messages are not neutral: they are
 * built by `notifyAdmins` (functions/src/index.ts) and interpolate real
 * identity and content directly —
 *
 *   report.user   → `${reporter.name} → ${reported.name}: ${reason}`
 *   venue_premium → `${owner.name} → "${venue}" (6 ay premium): 99 AZN`
 *
 * Before this, that stream was ungated, so a role defined not to see
 * personal data (`analyst`) would have read reporter names and
 * complaint text on every screen, and `finance` — which cannot open the
 * reports queue or the user list — would have read the same thing in
 * summary form. Filtering by role at the page level while leaving the
 * bell open would have been a boundary with a hole in the frame.
 *
 * Filtering is by notification TYPE rather than by a single
 * all-or-nothing permission, because the collection mixes two
 * unrelated concerns: moderation events and payment events. A coarse
 * gate would have to either show finance the complaint queue or hide
 * payment alerts from the one role that acts on them.
 */

/** Payment/billing events — the finance workspace. */
const PAYMENT_TYPE_PREFIXES = ["payment.", "refund.", "iap."] as const;
const PAYMENT_TYPES = [
  "boost_fee",
  "offer_placement_fee",
  "venue_subscription",
  "venue_premium",
  "pinbox_order",
] as const;

/** Moderation events — names and free-text complaint bodies. */
const REPORT_TYPE_PREFIX = "report.";

export type AdminNotificationCategory = "payment" | "report" | "other";

export function notificationCategory(type: string): AdminNotificationCategory {
  if (PAYMENT_TYPE_PREFIXES.some((p) => type.startsWith(p))) return "payment";
  if ((PAYMENT_TYPES as readonly string[]).includes(type)) return "payment";
  if (type.startsWith(REPORT_TYPE_PREFIX)) return "report";
  return "other";
}

/**
 * `other` covers anything unrecognised — including notification types
 * added later that this file has not been taught about. It is gated on
 * `manageAdmins` (admin only) on purpose: an unknown message's contents
 * are unknown, so the narrowest audience is the safe default. A new
 * type that should reach a wider role is a deliberate edit here, not
 * something that leaks by default.
 */
export function canSeeNotification(role: AdminRole | null | undefined, type: string): boolean {
  if (!hasPermission(role, "viewAdminNotifications")) return false;
  switch (notificationCategory(type)) {
    case "payment":
      return hasPermission(role, "viewPayments");
    case "report":
      return hasPermission(role, "manageFeedback");
    case "other":
      return hasPermission(role, "manageAdmins");
  }
}
