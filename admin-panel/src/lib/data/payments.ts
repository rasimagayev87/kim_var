import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

/** Mirrors the state machine in `functions/src/index.ts`
 * (`processPaymentRefund`/`expireVenueRevisionDeadlines`) and
 * `setVenueStatus` (admin panel) exactly — same 5 strings. */
export type PaymentStatus = "pending" | "completed" | "revision_pending" | "refund_pending" | "refunded";
export type PaymentStatusFilter = "all" | PaymentStatus;

export interface AdminPaymentRow {
  id: string;
  ownerId: string;
  ownerName: string;
  ownerUsername: string | null;
  venueId: string | null;
  venueName: string | null;
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
    value === "revision_pending" ||
    value === "refund_pending" ||
    value === "refunded"
    ? value
    : "pending";
}

/**
 * No real payment provider is wired yet (see `processPaymentRefund`'s
 * doc comment) — this list, sorted with `refund_pending` surfaced
 * first, IS the admin's refund queue until one exists. `markPaymentRefunded`
 * (actions/payments.ts) is how an admin closes one out after handling
 * it manually (bank transfer, etc.).
 */
export async function listPayments({ status }: { status: PaymentStatusFilter }): Promise<AdminPaymentRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("payments");
  if (status !== "all") {
    query = query.where("status", "==", status);
  }

  const snap = await query.orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();

  const ownerIds = [...new Set(snap.docs.map((doc) => doc.data().ownerId as string))];
  const venueIds = [...new Set(snap.docs.map((doc) => doc.data().venueId as string | undefined).filter(Boolean))] as string[];
  const [ownerDocs, venueDocs] = await Promise.all([
    Promise.all(ownerIds.map((uid) => db.collection("users").doc(uid).get())),
    Promise.all(venueIds.map((id) => db.collection("venues").doc(id).get())),
  ]);
  const ownerByUid = new Map(ownerDocs.map((doc) => [doc.id, doc.data()]));
  const venueById = new Map(venueDocs.map((doc) => [doc.id, doc.data()]));

  return snap.docs.map((doc) => {
    const data = doc.data();
    const owner = ownerByUid.get(data.ownerId as string);
    const venueId = (data.venueId as string) || null;
    const venue = venueId ? venueById.get(venueId) : undefined;
    const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    const updatedAt = data.updatedAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      ownerId: data.ownerId as string,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      ownerUsername: (owner?.username as string) ?? null,
      venueId,
      venueName: (venue?.name as string) ?? null,
      type: (data.type as string) ?? "venue_listing",
      amount: (data.amount as number) ?? 0,
      currency: (data.currency as string) ?? "AZN",
      status: parseStatus(data.status),
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
      updatedAt: updatedAt ? updatedAt.toDate().toISOString() : null,
    };
  });
}
