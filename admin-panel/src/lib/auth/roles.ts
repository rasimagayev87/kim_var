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
