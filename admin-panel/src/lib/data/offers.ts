import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

export type OfferStatus = "active" | "pending" | "rejected";
export type OfferStatusFilter = "all" | OfferStatus;

export interface AdminOfferRow {
  id: string;
  title: string;
  venueId: string;
  venueName: string;
  venuePhotoUrl: string | null;
  ownerId: string;
  ownerName: string;
  status: OfferStatus;
  startDate: string | null;
  endDate: string | null;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): OfferStatus {
  return value === "pending" || value === "rejected" ? value : "active";
}

function toIso(value: unknown): string | null {
  const ts = value as FirebaseFirestore.Timestamp | undefined;
  return ts ? ts.toDate().toISOString() : null;
}

export async function listOffers({
  status,
  search,
}: {
  status: OfferStatusFilter;
  search: string;
}): Promise<AdminOfferRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("offers");
  if (status !== "all") {
    query = query.where("status", "==", status);
  }

  const snap = await query.orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();
  let rows = await attachOwners(snap.docs);

  const key = search.trim().toLowerCase();
  if (key) {
    rows = rows.filter(
      (row) => row.title.toLowerCase().includes(key) || row.venueName.toLowerCase().includes(key),
    );
  }

  return rows;
}

export async function getOfferDetail(id: string): Promise<AdminOfferRow | null> {
  const doc = await getAdminDb().collection("offers").doc(id).get();
  if (!doc.exists) return null;
  const [row] = await attachOwners([doc as FirebaseFirestore.QueryDocumentSnapshot]);
  return row;
}

async function attachOwners(docs: FirebaseFirestore.QueryDocumentSnapshot[]): Promise<AdminOfferRow[]> {
  const db = getAdminDb();
  const ownerIds = [...new Set(docs.map((doc) => doc.data().ownerId as string))];
  const ownerDocs = await Promise.all(ownerIds.map((uid) => db.collection("users").doc(uid).get()));
  const ownerByUid = new Map(ownerDocs.map((doc) => [doc.id, doc.data()]));

  return docs.map((doc) => {
    const data = doc.data();
    const owner = ownerByUid.get(data.ownerId as string);
    return {
      id: doc.id,
      title: (data.title as string) ?? "",
      venueId: data.venueId as string,
      venueName: (data.venueName as string) ?? "",
      venuePhotoUrl: (data.venuePhotoUrl as string) ?? null,
      ownerId: data.ownerId as string,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      status: parseStatus(data.status),
      startDate: toIso(data.startDate),
      endDate: toIso(data.endDate),
      createdAt: toIso(data.createdAt),
    };
  });
}
