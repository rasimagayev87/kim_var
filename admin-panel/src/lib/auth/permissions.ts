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
    moderateOffers: true,
    broadcastNotifications: true,
    manageFeedback: true,
    manageAdmins: true,
  },
  moderator: {
    manageUsers: false,
    moderateVenues: true,
    moderateOffers: true,
    broadcastNotifications: false,
    manageFeedback: true,
    manageAdmins: false,
  },
} as const satisfies Record<AdminRole, Record<string, boolean>>;

export type Permission = keyof (typeof PERMISSION_MATRIX)["admin"];

export function hasPermission(role: AdminRole | null | undefined, permission: Permission): boolean {
  if (!role) return false;
  return PERMISSION_MATRIX[role][permission];
}
