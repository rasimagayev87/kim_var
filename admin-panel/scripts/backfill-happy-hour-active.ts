/**
 * One-time backfill for the new `Offer.happyHourActive` field — every
 * offer created before this feature shipped has no value for it, and
 * the Discover/venue-detail queries now filter on
 * `happyHourActive == true`, so without this backfill every existing
 * offer (not just Happy Hour ones) would silently vanish from those
 * lists the moment the updated client ships.
 *
 * Sets `happyHourActive: true` on every offer that doesn't already
 * have the field — safe/idempotent to re-run. For offers whose
 * `offerType` is `happyHour`, this write immediately re-triggers
 * `maintainHappyHourActiveFlag` (Cloud Function), which corrects it to
 * the real computed value (true/false depending on the current time)
 * within moments — this script deliberately doesn't duplicate that
 * day/time logic itself.
 *
 * Run once, after deploying the `maintainHappyHourActiveFlag`/
 * `refreshHappyHourOfferStatus` functions and BEFORE releasing the
 * client build that adds the `happyHourActive` query filter:
 *   npx tsx --env-file=.env.local scripts/backfill-happy-hour-active.ts
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

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

async function main() {
  const db = initAdmin();
  const snap = await db.collection("offers").get();
  const toBackfill = snap.docs.filter((doc) => doc.data().happyHourActive === undefined);
  console.log(`${snap.size} offers total, ${toBackfill.length} missing happyHourActive.`);

  const batchSize = 400;
  for (let i = 0; i < toBackfill.length; i += batchSize) {
    const batch = db.batch();
    for (const doc of toBackfill.slice(i, i + batchSize)) {
      batch.update(doc.ref, { happyHourActive: true });
    }
    await batch.commit();
    console.log(`Backfilled ${Math.min(i + batchSize, toBackfill.length)}/${toBackfill.length}`);
  }

  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
