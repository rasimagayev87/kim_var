/**
 * The role vocabulary, deliberately free of every import.
 *
 * This used to live in `session.ts`, which begins with
 * `import "server-only"` and pulls in the Admin SDK. That was fine while
 * only Server Components read it — but the five-role work needs the role
 * LIST in client components too (the admin roster's role picker), and
 * importing it from there dragged `server-only` and `firebase-admin`
 * into the browser bundle, failing the build with 68 errors about
 * `child_process`.
 *
 * Keeping the vocabulary here and the session machinery in `session.ts`
 * means both sides can name a role without either side inheriting the
 * other's dependencies. Same reasoning as `chat-media-path.ts` on the
 * Cloud Functions side: the pure part is separated so it can be used —
 * and unit-tested — without the runtime around it.
 */

/**
 * The five roles this panel understands.
 *
 * `admin` is a strict superset of every other role: there is no
 * permission any role holds that `admin` does not. That was deliberate
 * — the alternative (genuine separation of duties, where e.g. only
 * `finance` may act on financial reports) would leave the one role that
 * creates and removes the others unable to act in areas it is
 * nonetheless accountable for, and `changeAdminRole` refuses
 * self-changes, so an admin could not even grant themselves the
 * missing role.
 */
export type AdminRole = "admin" | "moderator" | "finance" | "support" | "analyst";

/** Every valid role, for runtime validation of values that arrive over
 * the network (Server Action arguments, custom claims) and for UI that
 * offers a choice of role. */
export const ADMIN_ROLES: readonly AdminRole[] = ["admin", "moderator", "finance", "support", "analyst"];

export function isAdminRole(value: unknown): value is AdminRole {
  return typeof value === "string" && (ADMIN_ROLES as readonly string[]).includes(value);
}

/**
 * The role to DISPLAY for a roster entry, or `null` when the stored
 * value is not a role this build knows.
 *
 * Separate from `isAdminRole` only so the roster read has one named
 * thing to call and one thing to test. The `null` is deliberate
 * hardening (RBAC-B): the previous roster read rendered any
 * unrecognised value as a full "admin" row, so on the one screen whose
 * job is showing who holds which privileges, the safest-looking answer
 * was also the most wrong one.
 *
 * That hardening was right; its list of valid roles was not. It was
 * written as `data.role === "admin" || data.role === "moderator"` and
 * never widened when the matrix grew to five, so `finance`, `support`
 * and `analyst` all rendered as "naməlum rol" — while working
 * perfectly, since authorization reads the custom claim and never this
 * field. Deriving from `ADMIN_ROLES` is what keeps the two from
 * drifting apart again.
 *
 * This value is for DISPLAY. Never make an access decision from it:
 * `admins/{uid}` is a roster index, and the custom claim is the
 * authority.
 */
export function rosterRole(value: unknown): AdminRole | null {
  return isAdminRole(value) ? value : null;
}
