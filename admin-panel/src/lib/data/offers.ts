import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";
import { birthdayDeadlineState } from "@/lib/birthday-deadline";

/** `expired` is written by `expireStaleListings` (Cloud Function) once
 * an approved campaign's `endDate` passes. Users never saw such a
 * campaign — every discovery fetch filters on `endDate` — but this
 * screen listed it as active until the status itself moved. */
export type OfferStatus = "approved" | "pending" | "needs_revision" | "rejected" | "expired";
export type OfferStatusFilter = "all" | OfferStatus;

export type OfferType = "discount" | "gift" | "buyOneGetOne" | "fixedPrice" | "happyHour" | "firstVisit" | "birthday";

export const OFFER_TYPE_LABELS: Record<OfferType, string> = {
  discount: "Endirim",
  gift: "Hədiyyə",
  buyOneGetOne: "1+1 Hədiyyə",
  fixedPrice: "Sabit qiymət",
  happyHour: "Happy Hour",
  firstVisit: "İlk ziyarət",
  birthday: "Doğum günü",
};

export interface AdminOfferRow {
  id: string;
  title: string;
  /** The offer's own free-text description — the actual content a
   * moderator needs to read, as distinct from `venueName` (who's
   * posting it). This is exactly what was missing before: a reviewer
   * had no way to see what the offer actually said. */
  description: string;
  /** The offer's own photo — was previously shadowed entirely by
   * `venuePhotoUrl` on the detail page, so a moderator never saw what
   * image the owner actually attached. */
  imageUrl: string | null;
  category: string;
  offerType: OfferType;
  /** Percentage for `discount`/`happyHour`, AZN amount for
   * `fixedPrice`. Null for `gift`/`buyOneGetOne`/`firstVisit`/`birthday`. */
  discountValue: number | null;
  terms: string | null;
  activeHoursStart: string | null;
  activeHoursEnd: string | null;
  activeDays: string[];
  personalMessage: string | null;
  address: string | null;
  venueId: string;
  venueName: string;
  venuePhotoUrl: string | null;
  ownerId: string;
  ownerName: string;
  status: OfferStatus;
  reviewNote: string | null;
  startDate: string | null;
  endDate: string | null;
  createdAt: string | null;
  /** Only set while `status === 'needs_revision'` — see `setOfferStatus`. */
  revisionDeadline: string | null;
  /** Backing `payments/{paymentId}` doc, if any — see `Offer.paymentId`
   * in the Flutter app. Null for offers created before that field
   * existed. */
  paymentId: string | null;
  /** `{YYYY-MM-DD}_{venueId}` for a birthday campaign, null otherwise.
   * Read here purely so the queue can show its 13:00 deadline — see
   * `birthday-deadline.ts`. */
  birthdayMatchId: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): OfferStatus {
  return value === "pending" || value === "needs_revision" || value === "rejected" || value === "expired"
    ? value
    : "approved";
}

function parseOfferType(value: unknown): OfferType {
  return value === "gift" ||
    value === "buyOneGetOne" ||
    value === "fixedPrice" ||
    value === "happyHour" ||
    value === "firstVisit" ||
    value === "birthday"
    ? value
    : "discount";
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

  // Today's birthday campaigns float to the top of the pending queue.
  //
  // Everything else here can wait until tomorrow; a birthday campaign
  // cannot. It has to be approved before 13:00 or it misses the
  // publication its owner was told to aim for, and `createdAt desc`
  // gives it no more prominence than an offer with a week of slack.
  // Sorting is the half of the fix that works whatever the moderator
  // is looking at; the badge in `offers-table.tsx` is the half that
  // explains why.
  if (status === "pending") {
    const now = new Date();
    rows = [...rows].sort((a, b) => {
      const aUrgent = birthdayDeadlineState(a.birthdayMatchId, now).kind === "pending" ? 0 : 1;
      const bUrgent = birthdayDeadlineState(b.birthdayMatchId, now).kind === "pending" ? 0 : 1;
      return aUrgent - bUrgent;
    });
  }

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
    const activeHours = data.activeHours as { start?: string; end?: string } | undefined;
    return {
      id: doc.id,
      title: (data.title as string) ?? "",
      description: (data.description as string) ?? "",
      imageUrl: (data.imageUrl as string) ?? null,
      category: (data.category as string) ?? "other",
      offerType: parseOfferType(data.offerType),
      discountValue: (data.discountValue as number | undefined) ?? null,
      terms: (data.terms as string) || null,
      activeHoursStart: activeHours?.start ?? null,
      activeHoursEnd: activeHours?.end ?? null,
      activeDays: (data.activeDays as string[] | undefined) ?? [],
      personalMessage: (data.personalMessage as string) || null,
      address: (data.address as string) || null,
      venueId: data.venueId as string,
      venueName: (data.venueName as string) ?? "",
      venuePhotoUrl: (data.venuePhotoUrl as string) ?? null,
      ownerId: data.ownerId as string,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      status: parseStatus(data.status),
      reviewNote: (data.reviewNote as string) || null,
      startDate: toIso(data.startDate),
      endDate: toIso(data.endDate),
      createdAt: toIso(data.createdAt),
      revisionDeadline: toIso(data.revisionDeadline),
      paymentId: (data.paymentId as string) || null,
      birthdayMatchId: (data.birthdayMatchId as string) || null,
    };
  });
}
