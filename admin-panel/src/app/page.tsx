import { redirect } from "next/navigation";

import { getCurrentAdmin } from "@/lib/auth/server";

/**
 * Proxy already redirects `/` to /login or /dashboard before this ever
 * renders in normal operation — this is just the defense-in-depth
 * fallback for whatever reaches the route anyway.
 */
export default async function Home() {
  const admin = await getCurrentAdmin();
  redirect(admin ? "/dashboard" : "/login");
}
