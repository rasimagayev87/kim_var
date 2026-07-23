import "server-only";

import { getAdminAuth, getAdminDb } from "@/lib/firebase/admin";

export interface AdminUserRow {
  uid: string;
  firstName: string;
  lastName: string;
  username: string | null;
  photoUrl: string | null;
  phoneNumber: string | null;
  createdAt: string | null;
  isVerified: boolean;
  premium: boolean;
  /** Firebase Auth's `disabled` flag — NOT a Firestore field. Ban et/
   * Aç works by disabling the Auth account (kills sign-in / invalidates
   * their tokens), matching the spec's explicit "Firebase Auth
   * `disabled` flag" requirement rather than a client-checked
   * Firestore boolean a signed-in session could just ignore. */
  banned: boolean;
}

export type VerifiedFilter = "all" | "verified" | "unverified";
export type VipFilter = "all" | "vip" | "free";

/** Same Azerbaijani/Turkish İ/I/ı-insensitive normalization the mobile
 * app's own search boxes use (see e.g. `chats_tab.dart`'s
 * `_azSearchKey`) — kept consistent so "İbrahim" matches "ibrahim"
 * here exactly like it does in the app. */
function azSearchKey(value: string): string {
  return value.replace(/İ/g, "i").replace(/I/g, "i").replace(/ı/g, "i").toLowerCase();
}

/**
 * Fetches the most recent `FETCH_LIMIT` users and applies every
 * filter (search, verified, VIP) in-memory rather than as Firestore
 * `where` clauses — deliberately, to avoid needing a composite index
 * for every filter × `orderBy(createdAt)` combination. Same "bounded,
 * best-effort" shape as every search box in the mobile app itself
 * (fetch a page, filter client-side): fine at today's user-base size,
 * worth revisiting (real indexes, or a search service) if it ever
 * doesn't fit in one bounded fetch.
 */
const FETCH_LIMIT = 200;

export async function listUsers({
  search,
  verifiedFilter,
  vipFilter,
}: {
  search: string;
  verifiedFilter: VerifiedFilter;
  vipFilter: VipFilter;
}): Promise<AdminUserRow[]> {
  const snap = await getAdminDb().collection("users").orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();

  let rows = await attachBannedStatus(snap.docs.map(docToRow));

  if (verifiedFilter !== "all") {
    const wantVerified = verifiedFilter === "verified";
    rows = rows.filter((row) => row.isVerified === wantVerified);
  }
  if (vipFilter !== "all") {
    const wantVip = vipFilter === "vip";
    rows = rows.filter((row) => row.premium === wantVip);
  }

  const key = azSearchKey(search.trim());
  if (key) {
    rows = rows.filter((row) => {
      const haystack = azSearchKey(
        `${row.username ?? ""} ${row.firstName} ${row.lastName} ${row.phoneNumber ?? ""}`,
      );
      return haystack.includes(key);
    });
  }

  return rows;
}

export async function getUserDetail(uid: string): Promise<AdminUserRow | null> {
  const doc = await getAdminDb().collection("users").doc(uid).get();
  if (!doc.exists) return null;
  const [row] = await attachBannedStatus([docToRow(doc as FirebaseFirestore.QueryDocumentSnapshot)]);
  return row;
}

function docToRow(doc: FirebaseFirestore.QueryDocumentSnapshot): Omit<AdminUserRow, "banned"> {
  const data = doc.data();
  const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
  return {
    uid: doc.id,
    firstName: (data.firstName as string) ?? "",
    lastName: (data.lastName as string) ?? "",
    username: (data.username as string) ?? null,
    photoUrl: (data.photoUrl as string) ?? null,
    phoneNumber: (data.phoneNumber as string) ?? null,
    createdAt: createdAt ? createdAt.toDate().toISOString() : null,
    isVerified: (data.isVerified as boolean) ?? false,
    premium: (data.premium as boolean) ?? false,
  };
}

/** Cross-references Firebase Auth's `disabled` flag onto Firestore
 * rows — one batched `getUsers()` Auth SDK call per 100 uids (its own
 * limit), not a per-row round trip. */
async function attachBannedStatus(rows: Omit<AdminUserRow, "banned">[]): Promise<AdminUserRow[]> {
  if (rows.length === 0) return [];
  const auth = getAdminAuth();
  const disabledByUid = new Map<string, boolean>();

  for (let i = 0; i < rows.length; i += 100) {
    const batch = rows.slice(i, i + 100).map((row) => ({ uid: row.uid }));
    const result = await auth.getUsers(batch);
    for (const user of result.users) {
      disabledByUid.set(user.uid, user.disabled);
    }
  }

  return rows.map((row) => ({ ...row, banned: disabledByUid.get(row.uid) ?? false }));
}
