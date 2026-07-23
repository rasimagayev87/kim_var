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
const PUBLIC_PATHS = new Set(["/login", "/unauthorized"]);

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const cookieValue = request.cookies.get(SESSION_COOKIE_NAME)?.value;

  if (pathname === "/login") {
    // Already signed in with a valid session — no reason to show the
    // login form again.
    const session = await verifySessionCookie(cookieValue);
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
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
};
