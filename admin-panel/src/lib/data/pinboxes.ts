import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

/** Mirrors the literal strings written by the Flutter app's `PinBox.status`
 * (see `lib/features/pinbox/domain/entities/pinbox.dart`). `needs_revision`
 * mirrors Offer/Venue's own moderation shape (owner fixes and resubmits via
 * `resubmitPinBox`) — unlike those two, there's no `revisionDeadline`/
 * payment-refund side effect on this one, since a PinBox listing itself
 * carries no upfront fee to protect (see `setPinBoxStatus`'s own doc
 * comment). */
export type PinBoxStatus = "pending" | "active" | "soldOut" | "expired" | "rejected" | "needs_revision";
export type PinBoxStatusFilter = "all" | PinBoxStatus;

export interface AdminPinBoxRow {
  id: string;
  title: string;
  /** The box's own free-text description — the actual content a
   * moderator needs to read. Previously missing from this row entirely,
   * so the detail page had no way to show it. */
  description: string;
  address: string | null;
  venueId: string;
  venueName: string;
  venuePhotoUrl: string | null;
  ownerId: string;
  ownerName: string;
  imageUrl: string | null;
  originalPrice: number;
  pinboxPrice: number;
  stockTotal: number;
  stockRemaining: number;
  status: PinBoxStatus;
  reviewNote: string | null;
  pickupWindowStart: string | null;
  pickupWindowEnd: string | null;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): PinBoxStatus {
  return value === "active" ||
    value === "soldOut" ||
    value === "expired" ||
    value === "rejected" ||
    value === "needs_revision"
    ? value
    : "pending";
}

function toIso(value: unknown): string | null {
  const ts = value as FirebaseFirestore.Timestamp | undefined;
  return ts ? ts.toDate().toISOString() : null;
}

export async function listPinBoxes({
  status,
  search,
}: {
  status: PinBoxStatusFilter;
  search: string;
}): Promise<AdminPinBoxRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("pinboxes");
  if (status !== "all") {
    query = query.where("status", "==", status);
  }

  const snap = await query.orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();
  let rows = await attachOwners(snap.docs);

  const key = search.trim().toLowerCase();
  if (key) {
    rows = rows.filter((row) => row.title.toLowerCase().includes(key) || row.venueName.toLowerCase().includes(key));
  }

  return rows;
}

export async function getPinBoxDetail(id: string): Promise<AdminPinBoxRow | null> {
  const doc = await getAdminDb().collection("pinboxes").doc(id).get();
  if (!doc.exists) return null;
  const [row] = await attachOwners([doc as FirebaseFirestore.QueryDocumentSnapshot]);
  return row;
}

async function attachOwners(docs: FirebaseFirestore.QueryDocumentSnapshot[]): Promise<AdminPinBoxRow[]> {
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
      description: (data.description as string) ?? "",
      address: (data.address as string) || null,
      venueId: data.venueId as string,
      venueName: (data.venueName as string) ?? "",
      venuePhotoUrl: (data.venuePhotoUrl as string) ?? null,
      ownerId: data.ownerId as string,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      imageUrl: (data.imageUrl as string) ?? null,
      originalPrice: (data.originalPrice as number) ?? 0,
      pinboxPrice: (data.pinboxPrice as number) ?? 0,
      stockTotal: (data.stockTotal as number) ?? 0,
      stockRemaining: (data.stockRemaining as number) ?? 0,
      status: parseStatus(data.status),
      reviewNote: (data.reviewNote as string) || null,
      pickupWindowStart: toIso(data.pickupWindowStart),
      pickupWindowEnd: toIso(data.pickupWindowEnd),
      createdAt: toIso(data.createdAt),
    };
  });
}
