/**
 * One-off migration for the "Hesab gizliliyi" feature: explicitly sets
 * `accountPrivacy: "public"` on every existing `users/{uid}` doc that
 * doesn't already have the field — see [AccountPrivacy] in
 * lib/features/privacy/domain/entities/privacy_settings.dart. Client
 * code already falls back to `public` when the field is absent, so
 * this script isn't required for correctness; it exists to make the
 * migration decision (everyone starts public, no exceptions) explicit
 * and queryable in the data itself rather than implicit in code.
 *
 * Run once, then delete this file (session convention for one-off
 * backfills):
 *   npm run backfill-account-privacy
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
  const snapshot = await db.collection("users").get();

  const missing = snapshot.docs.filter((doc) => !("accountPrivacy" in doc.data()));
  console.log(`${snapshot.size} users total, ${missing.length} missing accountPrivacy.`);

  const BATCH_SIZE = 500;
  for (let i = 0; i < missing.length; i += BATCH_SIZE) {
    const chunk = missing.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.set(doc.ref, { accountPrivacy: "public" }, { merge: true });
    }
    await batch.commit();
    console.log(`Backfilled ${Math.min(i + BATCH_SIZE, missing.length)}/${missing.length}`);
  }

  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
