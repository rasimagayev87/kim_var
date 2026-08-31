import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";
import { rosterRole, type AdminRole } from "@/lib/auth/roles";

export interface AdminRosterRow {
  uid: string;
  email: string;
  /** `null` when the stored value is not a role this build knows —
   * see [rosterRole] for the reasoning and for why that check now
   * derives from `ADMIN_ROLES` instead of naming roles inline. */
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
      role: rosterRole(data.role),
      addedAt: addedAt ? addedAt.toDate().toISOString() : null,
      addedBy: (data.addedBy as string) ?? null,
    };
  });
}
