import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

export type PinBoxPayoutStatus = "pending" | "paid";
export type PinBoxPayoutStatusFilter = "all" | PinBoxPayoutStatus;

export interface AdminPinBoxPayoutRow {
  id: string;
  orderId: string;
  venueId: string;
  venueName: string;
  ownerId: string | null;
  ownerName: string | null;
  ownerUsername: string | null;
  pinboxId: string;
  pinboxTitle: string;
  quantity: number;
  grossAmount: number;
  commissionRate: number;
  commissionAmount: number;
  payoutAmount: number;
  currency: string;
  status: PinBoxPayoutStatus;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): PinBoxPayoutStatus {
  return value === "paid" ? "paid" : "pending";
}

/**
 * Backs the "PinBox Öhdəlikləri" page — one row per `venuePayouts` doc.
 * Each doc is written the moment a PinBox order's payment succeeds
 * (`applyPaymentOutcome`, functions/src/index.ts), not batched monthly —
 * doc id is the order id, venue/pinbox/owner denormalized at write time,
 * so this is a single collection read plus a `users` lookup for owner
 * display name, same pattern as `listPayments`.
 */
export async function listPinBoxPayouts({ status }: { status: PinBoxPayoutStatusFilter }): Promise<AdminPinBoxPayoutRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("venuePayouts");
  if (status !== "all") {
    query = query.where("status", "==", status);
  }

  const snap = await query.orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();

  const ownerIds = [...new Set(snap.docs.map((doc) => doc.data().ownerId as string | undefined).filter(Boolean))] as string[];
  const ownerDocs = await Promise.all(ownerIds.map((uid) => db.collection("users").doc(uid).get()));
  const ownerByUid = new Map(ownerDocs.map((doc) => [doc.id, doc.data()]));

  return snap.docs.map((doc) => {
    const data = doc.data();
    const ownerId = (data.ownerId as string | undefined) ?? null;
    const owner = ownerId ? ownerByUid.get(ownerId) : undefined;
    const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      orderId: (data.orderId as string) ?? doc.id,
      venueId: data.venueId as string,
      venueName: (data.venueName as string) ?? "Naməlum",
      ownerId,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : null,
      ownerUsername: (owner?.username as string) ?? null,
      pinboxId: (data.pinboxId as string) ?? "",
      pinboxTitle: (data.pinboxTitle as string) ?? "Naməlum",
      quantity: (data.quantity as number) ?? 1,
      grossAmount: (data.grossAmount as number) ?? 0,
      commissionRate: (data.commissionRate as number) ?? 0,
      commissionAmount: (data.commissionAmount as number) ?? 0,
      payoutAmount: (data.payoutAmount as number) ?? 0,
      currency: (data.currency as string) ?? "AZN",
      status: parseStatus(data.status),
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
    };
  });
}
