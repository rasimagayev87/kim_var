import "server-only";

import { getAdminAuth } from "@/lib/firebase/admin";

export const SESSION_COOKIE_NAME = "__session";

// Well under Firebase's 14-day cap on session cookies — short enough
// that a stolen or forgotten admin-panel session doesn't stay valid
// for weeks. `createSessionCookie` wants this in milliseconds.
export const SESSION_MAX_AGE_SECONDS = 60 * 60 * 24 * 5;

export type AdminRole = "admin" | "moderator";

export interface AdminSession {
  uid: string;
  email: string;
  role: AdminRole;
}

function roleFromClaims(claims: Record<string, unknown>): AdminRole | null {
  return claims.role === "admin" || claims.role === "moderator" ? claims.role : null;
}

/**
 * Verifies an ID token fresh off client sign-in and, ONLY if it
 * already carries a `role` custom claim, mints a session cookie.
 * Returns null (never a cookie) for a legitimately-authenticated
 * Firebase user who simply isn't an admin/moderator — the login route
 * turns that into a redirect to /unauthorized instead of a real
 * session, so a plain end-user account can never end up with a valid
 * admin-panel cookie no matter what it sends here.
 */
export async function createSessionFromIdToken(
  idToken: string,
): Promise<{ cookie: string; session: AdminSession } | null> {
  const auth = getAdminAuth();
  const decoded = await auth.verifyIdToken(idToken, true);
  const role = roleFromClaims(decoded);
  if (!role) return null;

  const cookie = await auth.createSessionCookie(idToken, {
    expiresIn: SESSION_MAX_AGE_SECONDS * 1000,
  });

  return { cookie, session: { uid: decoded.uid, email: decoded.email ?? "", role } };
}

/**
 * Verifies a session cookie VALUE (callers read it from either
 * `next/headers`'s `cookies()` in a Server Component/Route Handler, or
 * straight off `NextRequest.cookies` in Proxy — both just hand this a
 * string). `checkRevoked` costs an extra network round-trip, so it's
 * off by default since Proxy calls this on every request; turn it on
 * for anything where a stale-but-cryptographically-valid cookie would
 * matter, e.g. right after an admin's access is revoked.
 */
export async function verifySessionCookie(
  cookieValue: string | undefined,
  { checkRevoked = false }: { checkRevoked?: boolean } = {},
): Promise<AdminSession | null> {
  if (!cookieValue) return null;
  try {
    const decoded = await getAdminAuth().verifySessionCookie(cookieValue, checkRevoked);
    const role = roleFromClaims(decoded);
    if (!role) return null;
    return { uid: decoded.uid, email: decoded.email ?? "", role };
  } catch {
    // Expired, malformed, revoked (when checkRevoked) or otherwise
    // invalid — all treated the same: no session.
    return null;
  }
}
