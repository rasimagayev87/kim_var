import "server-only";

import { FieldPath } from "firebase-admin/firestore";

import { getAdminDb } from "@/lib/firebase/admin";

/**
 * Düzəliş Prompt 6 / K-11 added `cancelled`/`cancelled_after_payout`/
 * `debt` (`cancelPinBoxPayoutForRefund`, functions/src/index.ts) — a
 * PinBox order can now be refunded, which the previous 2-value type
 * (and its `parseStatus` fallback below) couldn't represent at all;
 * every unrecognized value silently became `"pending"`, which would
 * have made a cancelled payout reappear as a normal payable row here.
 */
export type PinBoxPayoutStatus = "pending" | "paid" | "cancelled" | "cancelled_after_payout" | "debt";
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
  /** Whether the buyer never collected this order — read from the
   * `pinboxOrders` document, not from the payout.
   *
   * The payout obligation is written when PAYMENT clears, not when the
   * box is handed over, so an uncollected order looks identical to a
   * collected one on this screen. The venue is still paid (Public Offer
   * §5), but "the customer did not come" is a fact the person
   * reconciling payouts should be able to see. */
  notCollected: boolean;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): PinBoxPayoutStatus {
  return value === "paid" ||
    value === "cancelled" ||
    value === "cancelled_after_payout" ||
    value === "debt"
    ? value
    : "pending";
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

  // Which of these orders the buyer never collected. One extra query
  // for the page, not one per row: `expirePinBoxOrders` marks them
  // `no_show`, and the payout document itself carries no such field
  // because it is written at payment time, before anyone knows.
  const notCollectedOrderIds = new Set<string>();
  if (snap.size > 0) {
    const orderIds = snap.docs.map((d) => (d.data().orderId as string) ?? d.id);
    for (let i = 0; i < orderIds.length; i += 30) {
      const chunk = orderIds.slice(i, i + 30);
      const orders = await db
        .collection("pinboxOrders")
        .where(FieldPath.documentId(), "in", chunk)
        .where("status", "==", "no_show")
        .get();
      for (const o of orders.docs) notCollectedOrderIds.add(o.id);
    }
  }

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
      notCollected: notCollectedOrderIds.has((data.orderId as string) ?? doc.id),
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
    };
  });
}
