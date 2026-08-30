import type { AdminRole } from "./session";

/**
 * Every role → action check lives here, in one place, instead of
 * scattered `role === "admin"` conditionals across screens and API
 * routes. Coarse today (2 roles, a handful of actions) on purpose —
 * full RBAC (per-resource grants, custom roles) isn't required yet —
 * but adding a 3rd role or a finer-grained permission later is a
 * matrix edit here, not a hunt-and-patch across the app.
 *
 * `moderator` = content moderation only, per the product spec: venues/
 * offers/feedback, never user management, broadcasts, or the admin
 * roster itself.
 */
const PERMISSION_MATRIX = {
  admin: {
    manageUsers: true,
    moderateVenues: true,
    manageVenues: true,
    moderateOffers: true,
    broadcastNotifications: true,
    manageFeedback: true,
    manageAdmins: true,
    moderateIdentityVerifications: true,
    managePayments: true,
  },
  moderator: {
    manageUsers: false,
    moderateVenues: true,
    manageVenues: false,
    moderateOffers: true,
    broadcastNotifications: false,
    manageFeedback: true,
    manageAdmins: false,
    // Government ID photos + a selfie are the most sensitive data this
    // app handles — gated at the same admin-only level as manageUsers
    // (which also grants permanent, identity-linked trust: VIP), not
    // the moderator-accessible level of ordinary content moderation.
    moderateIdentityVerifications: false,
    // P0 / H-7 — moving money is not content moderation. Every payment
    // action used to be gated on `moderateVenues`, which moderators
    // hold, on the reasoning that "every payment here originates from a
    // venue-listing decision". That reasoning covered where the
    // payments come FROM, not what the actions DO: `initiateRefund`
    // flips a payment to `refund_pending`, which fires the
    // `processPaymentRefund` trigger, which calls Epoint's real
    // `/reverse` API — an actual bank reversal, with no amount cap, no
    // second approval, and no MFA anywhere in this panel.
    // `markPinBoxPayoutPaid` is the mirror image: it writes off a
    // venue's outstanding balance as settled. A compromised or
    // dishonest moderator account could work through the payments list
    // reversing real charges.
    managePayments: false,
  },
} as const satisfies Record<AdminRole, Record<string, boolean>>;

export type Permission = keyof (typeof PERMISSION_MATRIX)["admin"];

export function hasPermission(role: AdminRole | null | undefined, permission: Permission): boolean {
  if (!role) return false;
  return PERMISSION_MATRIX[role][permission];
}
