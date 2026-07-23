import "server-only";

import { cookies } from "next/headers";

import { SESSION_COOKIE_NAME, verifySessionCookie, type AdminSession } from "./session";

/**
 * The current admin/moderator for this request — usable from any
 * Server Component, Route Handler, or Server Function. Returns null
 * if not signed in.
 *
 * Proxy already redirects unauthenticated requests away from
 * protected pages, so this is normally just for reading WHO is signed
 * in, not gating access on its own — but every Server Function should
 * still call it (or `requireAdmin`/`requirePermission` below) itself
 * rather than trusting Proxy alone. Next's own Proxy docs call this
 * out explicitly: a matcher change or a refactor that moves a Server
 * Function to a different route can silently drop Proxy coverage.
 *
 * Checks revocation (`checkRevoked: true`) — Proxy deliberately doesn't
 * (see its own doc comment: that check costs a network round-trip and
 * Proxy runs on every request), but this function is the actual
 * authorization boundary every page/action re-verifies against, and an
 * admin panel specifically needs "removed/demoted takes effect now,"
 * not "...within the cookie's remaining lifetime (up to 5 days)." The
 * Admin idarəetməsi module's remove/demote actions call
 * `revokeRefreshTokens` for exactly this reason — without this check
 * here, that call would be a no-op until the cookie expired on its own.
 */
export async function getCurrentAdmin(): Promise<AdminSession | null> {
  const cookieStore = await cookies();
  return verifySessionCookie(cookieStore.get(SESSION_COOKIE_NAME)?.value, { checkRevoked: true });
}
