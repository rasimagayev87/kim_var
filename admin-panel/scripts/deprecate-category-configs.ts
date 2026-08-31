/**
 * Marks `config/eventCategories` and `config/waitlistCategories` as
 * retired.
 *
 * Both used to hold a list of `VenueCategory` names that the Flutter UI
 * read to decide which venues could create Events / run a queue. No
 * server code ever consulted either: `firestore.rules` and
 * `joinWaitlist` checked a three-item blacklist instead, and the rules
 * file separately hardcoded the waitlist ten for its `reviews` gate. So
 * the documents were a source of truth for the UI and for nothing that
 * could actually enforce anything.
 *
 * The lists now live in code — `functions/src/venue-categories.ts`,
 * `firestore.rules`, and `venue.dart`, held identical by
 * `tests/rules/venue-categories.test.ts`. Nothing reads these documents
 * any more.
 *
 * They are NOT deleted. Deleting production data to tidy up is a worse
 * trade than leaving it labelled: this writes a `deprecated` marker so
 * that whoever opens the Firestore Console next sees why the values are
 * stale instead of trusting them, or worse, "fixing" them.
 *
 * Usage:
 *   npm run deprecate-category-configs
 *
 * Safe to re-run — it merges, so it neither duplicates nor clears the
 * existing `enabledCategories` array.
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const DEPRECATION = {
  deprecated: true,
  deprecatedAt: new Date("2026-08-31"),
  deprecatedReason:
    "Artıq oxunmur. Kateqoriya siyahıları koda köçürüldü: " +
    "functions/src/venue-categories.ts + firestore.rules + " +
    "lib/features/venues/domain/entities/venue.dart. Üçü " +
    "tests/rules/venue-categories.test.ts ilə sinxron saxlanılır. " +
    "Bu sənədi redaktə etmək heç bir davranışı dəyişmir.",
};

const DOC_IDS = ["eventCategories", "waitlistCategories"];

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

  for (const id of DOC_IDS) {
    const ref = db.collection("config").doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`config/${id}: mövcud deyil — atlanır`);
      continue;
    }
    if (snap.data()?.deprecated === true) {
      console.log(`config/${id}: artıq işarələnib — atlanır`);
      continue;
    }
    await ref.set(DEPRECATION, { merge: true });
    console.log(`config/${id}: deprecated olaraq işarələndi (mövcud dəyərlər saxlanıldı)`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
