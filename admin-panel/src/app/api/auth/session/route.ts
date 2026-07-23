import { cookies } from "next/headers";
import { NextResponse } from "next/server";

import { createSessionFromIdToken, SESSION_COOKIE_NAME, SESSION_MAX_AGE_SECONDS } from "@/lib/auth/session";

/**
 * POST { idToken } — exchanges a fresh Firebase ID token (client just
 * signed in) for this app's own HttpOnly session cookie. Refuses to
 * mint a cookie at all for a Firebase user with no `role` custom
 * claim, so a valid-but-non-admin account can never end up with a
 * working admin-panel session no matter what it sends here — the
 * client turns a 403 into a redirect to /unauthorized instead.
 */
export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const idToken = body?.idToken;
  if (typeof idToken !== "string" || !idToken) {
    return NextResponse.json({ ok: false, error: "invalid-request" }, { status: 400 });
  }

  let result;
  try {
    result = await createSessionFromIdToken(idToken);
  } catch {
    return NextResponse.json({ ok: false, error: "invalid-token" }, { status: 401 });
  }

  if (!result) {
    return NextResponse.json({ ok: false, error: "no-role" }, { status: 403 });
  }

  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE_NAME, result.cookie, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_MAX_AGE_SECONDS,
  });

  return NextResponse.json({ ok: true, role: result.session.role });
}

/** Logout — just drops the cookie; the client is responsible for also
 * calling `firebaseAuth.signOut()` to clear its own local state. */
export async function DELETE() {
  const cookieStore = await cookies();
  cookieStore.delete(SESSION_COOKIE_NAME);
  return NextResponse.json({ ok: true });
}
