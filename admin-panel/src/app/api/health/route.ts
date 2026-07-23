import { NextResponse } from "next/server";

import { getAdminAuth } from "@/lib/firebase/admin";

/**
 * Confirms the Admin SDK can actually reach the `kim-var-73ce9`
 * Firebase project — lists up to 1 Auth user if the service-account
 * credentials in .env.local are valid, surfaces a clear error
 * otherwise. Temporary Phase 1 verification endpoint; later phases
 * (real dashboard/API routes) exercise the same `adminAuth`/`adminDb`
 * wiring, so this can be deleted once one of those is live.
 */
export async function GET() {
  try {
    const result = await getAdminAuth().listUsers(1);
    return NextResponse.json({
      ok: true,
      projectId: process.env.FIREBASE_PROJECT_ID,
      sampleUserCount: result.users.length,
    });
  } catch (error) {
    return NextResponse.json(
      { ok: false, error: error instanceof Error ? error.message : String(error) },
      { status: 500 },
    );
  }
}
