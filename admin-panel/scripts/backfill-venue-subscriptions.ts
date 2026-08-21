/**
 * One-off migration: sets `subscriptionRenewsAt` (createdAt + 30 days,
 * or now + 30 days if that's already in the past) on every `approved`
 * venue that predates the "aylıq abunə" model (see
 * `FirebaseVenueRepository.createVenue`'s own doc comment) and so has
 * no `subscriptionRenewsAt` field yet. `renewVenueSubscriptions`
 * (scheduled Cloud Function, functions/src/index.ts) only ever queries
 * `subscriptionRenewsAt <= now`, so a venue missing the field entirely
 * would otherwise never enter the billing cycle at all — this closes
 * that gap once, by hand, rather than teaching the scheduled function
 * to query for an absent field (Firestore has no clean way to do that).
 *
 * Safe to re-run: only touches docs that still lack the field, so a
 * venue already backfilled (or created after this migration) is a
 * no-op on a second run.
 *
 * Usage:
 *   npm run backfill-venue-subscriptions
 */
import { cert, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";

function initAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY in .env.local");
  }

  initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
  return getFirestore();
}

const SUBSCRIPTION_CYCLE_MS = 30 * 24 * 60 * 60 * 1000;

async function main() {
  const db = initAdmin();
  const now = new Date();

  const snap = await db.collection("venues").where("status", "==", "approved").get();
  const missing = snap.docs.filter((doc) => !("subscriptionRenewsAt" in doc.data()));

  if (missing.length === 0) {
    console.log("No approved venues missing subscriptionRenewsAt — nothing to do.");
    return;
  }

  let batch = db.batch();
  let opsInBatch = 0;
  let total = 0;

  for (const doc of missing) {
    const createdAt = (doc.data().createdAt as Timestamp | undefined)?.toDate();
    const firstCycleEnd = createdAt ? new Date(createdAt.getTime() + SUBSCRIPTION_CYCLE_MS) : now;
    const renewsAt = firstCycleEnd.getTime() > now.getTime() ? firstCycleEnd : now;

    batch.update(doc.ref, {
      subscriptionRenewsAt: Timestamp.fromDate(renewsAt),
      updatedAt: FieldValue.serverTimestamp(),
    });
    opsInBatch++;
    total++;

    // Firestore batches cap at 500 writes.
    if (opsInBatch === 500) {
      await batch.commit();
      batch = db.batch();
      opsInBatch = 0;
    }
  }
  if (opsInBatch > 0) await batch.commit();

  console.log(`Backfilled subscriptionRenewsAt on ${total} venue(s).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
