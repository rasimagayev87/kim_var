import { NextResponse, type NextRequest } from "next/server";

import { SESSION_COOKIE_NAME, verifySessionCookie } from "@/lib/auth/session";

// Next.js 16 renamed `middleware.ts` → `proxy.ts` (same file convention,
// new name/export — see node_modules/next/dist/docs/.../proxy.md) and,
// as of this same version, Proxy defaults to the Node.js runtime rather
// than Edge. That's what makes it safe to call the Admin SDK directly
// in here — `verifySessionCookie` is pure JWT verification (no network
// round-trip unless `checkRevoked` is passed), so this stays cheap on
// every request despite running here instead of deeper in the app.
//
// This is the FAST path, not the only trust boundary: every Server
// Function/Route Handler that does anything sensitive re-verifies the
// session itself (see lib/auth/server.ts's doc comment) — Proxy
// coverage can silently change on a refactor, per Next's own guidance.
// Epoint's success_redirect_url/error_redirect_url (see
// functions/src/index.ts's EPOINT_SUCCESS_REDIRECT_URL/
// EPOINT_ERROR_REDIRECT_URL) — a paying customer's browser, which never
// has an admin session, must reach these without being bounced to
// /login.
const PUBLIC_PATHS = new Set(["/login", "/unauthorized", "/payment/success", "/payment/error"]);

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const cookieValue = request.cookies.get(SESSION_COOKIE_NAME)?.value;

  if (pathname === "/login") {
    // Already signed in with a valid session — no reason to show the
    // login form again. Deliberately `checkRevoked: true` here (unlike
    // the general per-request check below) — this path only runs on an
    // actual /login visit, not every navigation, so the extra network
    // round-trip is cheap. It matters because a cookie can be
    // cryptographically valid (unexpired, correctly signed) for a
    // Firebase user that no longer exists — e.g. an admin's Auth
    // account got deleted while their browser still held a live
    // session. With `checkRevoked: false` (this file's own default,
    // still correct for the general check), that stale cookie reads as
    // "valid" here and redirects to /dashboard, while `getCurrentAdmin`
    // there (lib/auth/server.ts, `checkRevoked: true`) correctly
    // detects the account is gone and redirects back to /login — an
    // infinite loop between the two, confirmed via a live isolated test
    // (mint a cookie, delete the user, compare both checks) while
    // diagnosing exactly this. Using the same stricter check here
    // breaks the cycle at its source instead of only downstream.
    const session = await verifySessionCookie(cookieValue, { checkRevoked: true });
    if (session) {
      return NextResponse.redirect(new URL("/dashboard", request.url));
    }
    return NextResponse.next();
  }

  if (PUBLIC_PATHS.has(pathname)) {
    return NextResponse.next();
  }

  const session = await verifySessionCookie(cookieValue);
  if (!session) {
    const response = NextResponse.redirect(new URL("/login", request.url));
    // Clears anything stale/invalid so it doesn't keep bouncing every
    // request through a doomed verify attempt.
    response.cookies.delete(SESSION_COOKIE_NAME);
    return response;
  }

  return NextResponse.next();
}

export const config = {
  // peakpin-logo.png (Sidebar logo, /public) — same reasoning as
  // favicon.ico: a static asset that must load before/without a
  // session (Sidebar renders it even in an about-to-redirect state),
  // never something that needs the auth gate.
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|peakpin-logo.png).*)"],
};
