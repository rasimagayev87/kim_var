import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

/** Mirrors the state machine in `functions/src/index.ts`
 * (`processPaymentRefund`/`expireListingRevisionDeadlines`) and
 * `setVenueStatus`/`setOfferStatus` (admin panel) exactly — same 5 strings. */
export type PaymentStatus = "pending" | "completed" | "failed" | "revision_pending" | "refund_pending" | "refunded";
export type PaymentStatusFilter = "all" | PaymentStatus;

/** "pinboxOrder" payments (`type: "pinbox_order"`) point at a `pinboxOrders`
 * doc, not a `venues`/`offers` doc — there's no admin detail page for it yet,
 * so callers must not assume every listingType has a linkable route. */
export type ListingType = "venue" | "offer" | "pinboxOrder";

export interface AdminPaymentRow {
  id: string;
  ownerId: string;
  ownerName: string;
  ownerUsername: string | null;
  listingType: ListingType | null;
  listingId: string | null;
  /** Resolved from the `venues`/`offers` collection matching
   * [listingType] — a venue's `name` or an offer's `title`. */
  listingName: string | null;
  type: string;
  amount: number;
  currency: string;
  status: PaymentStatus;
  createdAt: string | null;
  updatedAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): PaymentStatus {
  return value === "pending" ||
    value === "completed" ||
    value === "failed" ||
    value === "revision_pending" ||
    value === "refund_pending" ||
    value === "refunded"
    ? value
    : "pending";
}

function parseListingType(value: unknown): ListingType | null {
  return value === "venue" || value === "offer" || value === "pinboxOrder" ? value : null;
}

/**
 * No real payment provider is wired yet (see `processPaymentRefund`'s
 * doc comment) — this list, sorted with `refund_pending` surfaced
 * first, IS the admin's refund queue until one exists. `markPaymentRefunded`
 * (actions/payments.ts) is how an admin closes one out after handling
 * it manually (bank transfer, etc.). Covers both venue and offer
 * listing payments — distinguished by `listingType`, resolved against
 * whichever of `venues`/`offers` it points at for display.
 */
export async function listPayments({ status }: { status: PaymentStatusFilter }): Promise<AdminPaymentRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("payments");
  if (status !== "all") {
    query = query.where("status", "==", status);
  }

  const snap = await query.orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();

  const ownerIds = [...new Set(snap.docs.map((doc) => doc.data().ownerId as string))];
  const venueIds = [
    ...new Set(
      snap.docs
        .filter((doc) => doc.data().listingType === "venue")
        .map((doc) => doc.data().listingId as string | undefined)
        .filter(Boolean),
    ),
  ] as string[];
  const offerIds = [
    ...new Set(
      snap.docs
        .filter((doc) => doc.data().listingType === "offer")
        .map((doc) => doc.data().listingId as string | undefined)
        .filter(Boolean),
    ),
  ] as string[];
  const [ownerDocs, venueDocs, offerDocs] = await Promise.all([
    Promise.all(ownerIds.map((uid) => db.collection("users").doc(uid).get())),
    Promise.all(venueIds.map((id) => db.collection("venues").doc(id).get())),
    Promise.all(offerIds.map((id) => db.collection("offers").doc(id).get())),
  ]);
  const ownerByUid = new Map(ownerDocs.map((doc) => [doc.id, doc.data()]));
  const venueById = new Map(venueDocs.map((doc) => [doc.id, doc.data()]));
  const offerById = new Map(offerDocs.map((doc) => [doc.id, doc.data()]));

  return snap.docs.map((doc) => {
    const data = doc.data();
    const owner = ownerByUid.get(data.ownerId as string);
    const listingType = parseListingType(data.listingType);
    const listingId = (data.listingId as string) || null;
    const listingName =
      listingType === "venue"
        ? ((listingId ? venueById.get(listingId)?.name : undefined) as string | undefined) ?? null
        : listingType === "offer"
          ? ((listingId ? offerById.get(listingId)?.title : undefined) as string | undefined) ?? null
          : null;
    const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    const updatedAt = data.updatedAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      ownerId: data.ownerId as string,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      ownerUsername: (owner?.username as string) ?? null,
      listingType,
      listingId,
      listingName,
      type: (data.type as string) ?? "venue_listing",
      amount: (data.amount as number) ?? 0,
      currency: (data.currency as string) ?? "AZN",
      status: parseStatus(data.status),
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
      updatedAt: updatedAt ? updatedAt.toDate().toISOString() : null,
    };
  });
}
