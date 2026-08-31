import type { AdminRole } from "./roles";

/**
 * Every role → action check lives here, in one place, instead of
 * scattered `role === "admin"` conditionals across screens and API
 * routes. Adding a role or a permission is an edit to this one matrix,
 * not a hunt across the app.
 *
 * ── Reading this matrix ────────────────────────────────────────────
 * Permissions come in two shapes, and the split is what makes
 * "view-only" access expressible at all:
 *
 *   `viewX`   — may open the screen and read what is on it.
 *   `manageX` / `moderateX` / other verbs — may perform the actions on
 *               that screen.
 *
 * A role with `viewX: true, manageX: false` sees the page with its
 * action controls hidden AND is rejected by the Server Actions behind
 * them. Hiding a button is never the boundary; the action's own
 * `hasPermission` call is (see any file in lib/actions/).
 *
 * ── `admin` is a strict superset ───────────────────────────────────
 * There is no permission below that `admin` lacks. See `AdminRole`'s
 * own doc comment for why separation of duties was rejected here.
 *
 * ── Permissions with nothing to guard yet ──────────────────────────
 * Several entries are marked NO SURFACE YET. The screen or feature
 * they describe does not exist in this codebase — the permission is
 * defined anyway so that whoever builds it finds the access decision
 * already made and already reviewed, instead of inventing a second,
 * differently-named permission for the same thing. They are inert
 * today: nothing calls `hasPermission` with them.
 */
/**
 * ── The agreed matrix, and where each row lives in code ────────────
 *
 * ✅ full · 👁️ view only · ❌ no access
 *
 * | Area                      | admin | moderator | finance | support | analyst | permission(s) |
 * |---------------------------|-------|-----------|---------|---------|---------|---------------|
 * | Dashboard                 | ✅ | 👁️ | 👁️ | 👁️ | 👁️ | viewDashboard |
 * | Users                     | ✅ | 👁️ | ❌ | 👁️ | ❌ | viewUsers / manageUsers |
 * | User ban                  | ✅ | ✅ | ❌ | ❌ | ❌ | banUsers |
 * | Account deletion          | ✅ | ❌ | ❌ | ❌ | ❌ | deleteUsers |
 * | Venues                    | ✅ | ✅ | 👁️ | 👁️ | 👁️ | viewVenues / moderateVenues |
 * | Offers                    | ✅ | ✅ | 👁️ | 👁️ | 👁️ | viewOffers / moderateOffers |
 * | PinBox                    | ✅ | ✅ | ❌ | 👁️ | 👁️ | viewPinBoxes |
 * | Events                    | ✅ | ✅ | ❌ | 👁️ | 👁️ | viewEvents |
 * | Reports                   | ✅ | ✅ | ❌ | ✅ | ❌ | manageFeedback |
 * | VIP / subscriptions       | ✅ | 👁️ | ✅ | 👁️ | 👁️ | viewSubscriptions / manageSubscriptions |
 * | Boosts                    | ✅ | 👁️ | ✅ | 👁️ | 👁️ | viewBoosts / manageBoosts |
 * | Payments                  | ✅ | ❌ | ✅ | 👁️ | 👁️ | viewPayments / managePayments |
 * | Premium business payments | ✅ | ❌ | ✅ | 👁️ | 👁️ | viewPayments |
 * | PinBox payouts            | ✅ | ❌ | ✅ | 👁️ | 👁️ | viewPayments / managePayments |
 * | Refunds                   | ✅ | ❌ | ✅ | ❌ | ❌ | managePayments |
 * | Financial reports         | ✅ | ❌ | ✅ | ❌ | 👁️ | viewFinancials / manageFinancials |
 * | Epoint transactions       | ✅ | ❌ | ✅ | 👁️ | 👁️ | viewEpointTransactions |
 * | KYC                       | ✅ | ❌ | ❌ | ❌ | ❌ | moderateIdentityVerifications |
 * | Support messages          | ✅ | 👁️ | 👁️ | ✅ | 👁️ | viewSupportMessages / manageSupportMessages |
 * | Broadcasts                | ✅ | 👁️ | ❌ | ✅ | ❌ | viewBroadcasts / broadcastNotifications |
 * | Admin notification bell   | ✅ | ✅ | ✅ | ✅ | ❌ | viewAdminNotifications |
 * | Analytics                 | ✅ | 👁️ | 👁️ | 👁️ | ✅ | viewAnalytics |
 * | DAU/WAU/MAU               | ✅ | 👁️ | ❌ | ❌ | ✅ | viewEngagementMetrics |
 * | Revenue analytics         | ✅ | ❌ | ✅ | ❌ | ✅ | viewRevenue |
 * | Admins / roles            | ✅ | ❌ | ❌ | ❌ | ❌ | manageAdmins |
 * | System settings           | ✅ | ❌ | ❌ | ❌ | ❌ | manageSystemSettings |
 * | Audit logs                | ✅ | 👁️ | 👁️ | 👁️ | ❌ | viewAuditLogs |
 * | Export                    | ✅ | ❌ | ✅ finance only | ❌ | ❌ | exportData / exportFinancialData |
 *
 * TWO ROWS THAT LOOK LIKE ONE. "Notifications" is two unrelated
 * things and they resolve differently:
 *
 *   - BROADCASTS (`/notifications`) is the screen for sending push to
 *     users. `finance` has no business there and is denied outright.
 *   - The ADMIN NOTIFICATION BELL is rendered by the protected layout
 *     on every page. `finance` keeps it because payment and refund
 *     alerts are exactly what that role acts on; what it does NOT get
 *     is the moderation half, filtered out per notification TYPE by
 *     `notification-visibility.ts` rather than by this permission.
 *     `analyst` is denied the bell entirely, since even a payment
 *     alert names the venue owner.
 *
 * TWO SCREENS ON THE PAYMENTS AXIS, NOT THE SUBSCRIPTION ONE.
 * "Premium business payments" and "PinBox payouts" both list money
 * that moved, so both are gated by `viewPayments`, which excludes
 * `moderator` — the same separation P0 / H-7 exists to enforce.
 * `viewSubscriptions` (true for every role) describes subscription
 * STATE a moderator legitimately needs to see on a venue, and gating
 * a payments screen with it would have left that screen open.
 * `/premium-payments` has no action controls at all today, so its ✅
 * for admin/finance is view access to a read-only table;
 * `markPinBoxPayoutPaid` is gated by `managePayments`.
 */
const PERMISSION_MATRIX = {
  admin: {
    // ── view ──────────────────────────────────────────────────────
    viewDashboard: true,
    viewUsers: true,
    viewVenues: true,
    viewOffers: true,
    viewPinBoxes: true,
    viewEvents: true,
    viewSubscriptions: true,
    viewBoosts: true,
    viewPayments: true,
    viewFinancials: true,
    viewEpointTransactions: true,
    viewSupportMessages: true,
    viewBroadcasts: true,
    viewAnalytics: true,
    viewEngagementMetrics: true,
    viewRevenue: true,
    viewAuditLogs: true,
    viewAdminNotifications: true,
    // ── act ───────────────────────────────────────────────────────
    manageUsers: true,
    banUsers: true,
    deleteUsers: true,
    moderateVenues: true,
    manageVenues: true,
    moderateOffers: true,
    broadcastNotifications: true,
    manageFeedback: true,
    manageAdmins: true,
    moderateIdentityVerifications: true,
    managePayments: true,
    manageSubscriptions: true,
    manageBoosts: true,
    manageFinancials: true,
    manageSupportMessages: true,
    manageSystemSettings: true,
    exportData: true,
    exportFinancialData: true,
  },

  /** Content moderation. Gains user visibility and the ban action in
   * this revision (previously `/users` was closed to moderators
   * entirely and banning required `manageUsers`); permanent account
   * deletion stays admin-only. Sees no financial screen at all — that
   * separation was the point of P0 / H-7. */
  moderator: {
    viewDashboard: true,
    viewUsers: true,
    viewVenues: true,
    viewOffers: true,
    viewPinBoxes: true,
    viewEvents: true,
    viewSubscriptions: true,
    viewBoosts: true,
    viewPayments: false,
    viewFinancials: false,
    viewEpointTransactions: false,
    viewSupportMessages: true,
    viewBroadcasts: true,
    viewAnalytics: true,
    viewEngagementMetrics: true,
    viewRevenue: false,
    viewAuditLogs: true,
    viewAdminNotifications: true,
    manageUsers: false,
    banUsers: true,
    deleteUsers: false,
    moderateVenues: true,
    manageVenues: false,
    moderateOffers: true,
    broadcastNotifications: false,
    manageFeedback: true,
    manageAdmins: false,
    moderateIdentityVerifications: false,
    managePayments: false,
    manageSubscriptions: false,
    manageBoosts: false,
    manageFinancials: false,
    manageSupportMessages: false,
    manageSystemSettings: false,
    exportData: false,
    exportFinancialData: false,
  },

  /** Money. Deliberately cannot see the user list, reports, or KYC —
   * none of which it needs, all of which carry identity data. Venue and
   * offer screens stay visible because a payment is meaningless without
   * knowing which listing it belongs to. */
  finance: {
    viewDashboard: true,
    viewUsers: false,
    viewVenues: true,
    viewOffers: true,
    viewPinBoxes: false,
    viewEvents: false,
    viewSubscriptions: true,
    viewBoosts: true,
    viewPayments: true,
    viewFinancials: true,
    viewEpointTransactions: true,
    viewSupportMessages: true,
    viewBroadcasts: false,
    viewAnalytics: true,
    viewEngagementMetrics: false,
    viewRevenue: true,
    viewAuditLogs: true,
    viewAdminNotifications: true,
    manageUsers: false,
    banUsers: false,
    deleteUsers: false,
    moderateVenues: false,
    manageVenues: false,
    moderateOffers: false,
    broadcastNotifications: false,
    manageFeedback: false,
    manageAdmins: false,
    moderateIdentityVerifications: false,
    managePayments: true,
    manageSubscriptions: true,
    manageBoosts: true,
    manageFinancials: true,
    manageSupportMessages: false,
    manageSystemSettings: false,
    exportData: false,
    exportFinancialData: true,
  },

  /** Customer-facing. Reads user profiles to answer questions, and owns
   * reports and support conversations — but never edits a user, never
   * bans, and never touches money. */
  support: {
    viewDashboard: true,
    viewUsers: true,
    viewVenues: true,
    viewOffers: true,
    viewPinBoxes: true,
    viewEvents: true,
    viewSubscriptions: true,
    viewBoosts: true,
    viewPayments: true,
    viewFinancials: false,
    viewEpointTransactions: true,
    viewSupportMessages: true,
    viewBroadcasts: true,
    viewAnalytics: true,
    viewEngagementMetrics: false,
    viewRevenue: false,
    viewAuditLogs: true,
    viewAdminNotifications: true,
    manageUsers: false,
    banUsers: false,
    deleteUsers: false,
    moderateVenues: false,
    manageVenues: false,
    moderateOffers: false,
    broadcastNotifications: true,
    manageFeedback: true,
    manageAdmins: false,
    moderateIdentityVerifications: false,
    managePayments: false,
    manageSubscriptions: false,
    manageBoosts: false,
    manageFinancials: false,
    manageSupportMessages: true,
    manageSystemSettings: false,
    exportData: false,
    exportFinancialData: false,
  },

  /** Numbers only. Every screen carrying names, e-mail addresses, phone
   * numbers or report text is closed to this role — user list, reports,
   * audit logs, and the admin-notification feed (whose messages
   * interpolate reporter/owner names directly). What it can see is
   * either an aggregate or a listing, never a person.
   *
   * NOTE: as of this revision there is no analytics screen in the
   * codebase, so this role's own workspace does not exist yet — the
   * role is defined and enforced, its content comes later. */
  analyst: {
    viewDashboard: true,
    viewUsers: false,
    viewVenues: true,
    viewOffers: true,
    viewPinBoxes: true,
    viewEvents: true,
    viewSubscriptions: true,
    viewBoosts: true,
    viewPayments: true,
    viewFinancials: true,
    viewEpointTransactions: true,
    viewSupportMessages: true,
    viewBroadcasts: false,
    viewAnalytics: true,
    viewEngagementMetrics: true,
    viewRevenue: true,
    viewAuditLogs: false,
    viewAdminNotifications: false,
    manageUsers: false,
    banUsers: false,
    deleteUsers: false,
    moderateVenues: false,
    manageVenues: false,
    moderateOffers: false,
    broadcastNotifications: false,
    manageFeedback: false,
    manageAdmins: false,
    moderateIdentityVerifications: false,
    managePayments: false,
    manageSubscriptions: false,
    manageBoosts: false,
    manageFinancials: false,
    manageSupportMessages: false,
    manageSystemSettings: false,
    exportData: false,
    exportFinancialData: false,
  },
} as const satisfies Record<AdminRole, Record<string, boolean>>;

export type Permission = keyof (typeof PERMISSION_MATRIX)["admin"];

/**
 * Permissions that no screen or Server Action consumes yet, because the
 * feature they describe has not been built. Listed explicitly so the
 * gap is visible rather than inferred, and so a test can assert the
 * list stays honest as features land.
 *
 * Anyone building one of these screens: the access decision is already
 * made above — wire the existing permission rather than adding a new
 * one with a different name for the same thing.
 */
export const UNIMPLEMENTED_PERMISSIONS: readonly Permission[] = [
  "viewEvents", // no events screen (only /event-reports)
  "viewBoosts", // boosts are rows inside /payments, no dedicated screen
  "viewFinancials", // no financial-reports screen
  "viewEpointTransactions", // Epoint rows live inside /payments
  "viewSupportMessages", // `supportMessages` has no admin screen at all
  "viewAnalytics", // no /analytics screen
  "viewEngagementMetrics", // no DAU/WAU/MAU screen
  "manageBoosts",
  "manageFinancials",
  "manageSupportMessages",
  "manageSystemSettings", // no /settings screen
  "exportData", // no export exists anywhere
  "exportFinancialData",
];

export function hasPermission(role: AdminRole | null | undefined, permission: Permission): boolean {
  if (!role) return false;
  const row = PERMISSION_MATRIX[role];
  // Defensive: `role` is typed, but it originates from a custom claim.
  // `roleFromClaims` already rejects anything unrecognised, so this can
  // only fire if that allowlist and this matrix ever disagree — in
  // which case denying is the correct answer.
  if (!row) return false;
  return row[permission] ?? false;
}

/** The full matrix, for the roster UI and for tests. Read-only. */
export const PERMISSIONS_BY_ROLE = PERMISSION_MATRIX;
