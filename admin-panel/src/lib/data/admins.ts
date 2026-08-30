import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";
import type { AdminRole } from "@/lib/auth/session";

export interface AdminRosterRow {
  uid: string;
  email: string;
  /**
   * `null` when the stored value is neither `admin` nor `moderator`
   * (P0 follow-up / RBAC-B).
   *
   * This used to be `data.role === "moderator" ? "moderator" : "admin"`,
   * which rendered ANY unrecognised value — including one that leaves the
   * account unable to sign in at all, since `roleFromClaims` only accepts
   * those two — as a full "admin" row. On the one screen whose job is
   * showing who holds which privileges, the safest-looking answer was
   * also the most wrong one. Surfacing it as unknown makes a corrupt or
   * hand-edited roster entry visible instead of flattering it.
   */
  role: AdminRole | null;
  addedAt: string | null;
  addedBy: string | null;
}

/**
 * Reads from the `admins` roster collection, NOT Firebase Auth
 * directly — see firestore.rules' `admins/{uid}` doc comment for why:
 * there's no way to query Auth for "every user with a `role` custom
 * claim," only enumerate everyone and filter, which doesn't scale as
 * the real (non-admin) user base grows. This collection is a kept-in-
 * sync index of exactly the admins/moderators, nothing else.
 */
export async function listAdmins(): Promise<AdminRosterRow[]> {
  const snap = await getAdminDb().collection("admins").orderBy("addedAt", "desc").get();

  return snap.docs.map((doc) => {
    const data = doc.data();
    const addedAt = data.addedAt as FirebaseFirestore.Timestamp | undefined;
    return {
      uid: doc.id,
      email: (data.email as string) ?? "",
      role: data.role === "admin" || data.role === "moderator" ? data.role : null,
      addedAt: addedAt ? addedAt.toDate().toISOString() : null,
      addedBy: (data.addedBy as string) ?? null,
    };
  });
}
