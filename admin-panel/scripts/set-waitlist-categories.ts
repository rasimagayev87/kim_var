/**
 * Sets `config/waitlistCategories.enabledCategories` in Firestore — the
 * list of `VenueCategory` names allowed to turn on the walk-in
 * waitlist feature (see `waitlistCategoryConfigProvider` in
 * lib/features/waitlist/presentation/providers/waitlist_providers.dart).
 * A venue whose category isn't in this list never sees the "Növbə"
 * menu entry (unless it already has waitlist history), and its
 * `waitlistEnabled` gets forced off server-side the moment its category
 * moves out of this list (`disableVenueWaitlistOnIneligibleCategory`,
 * functions/src/index.ts).
 *
 * Run this by hand whenever the eligible category list changes:
 *   npm run set-waitlist-categories -- restaurant pub fastFood coffeeShop teaHouse karaoke sweetsShop gameHall spa carWash
 *
 * Category names must match `VenueCategory` enum values exactly (see
 * lib/features/venues/domain/entities/venue.dart).
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
  const categories = process.argv.slice(2);
  if (categories.length === 0) {
    console.error("Usage: npm run set-waitlist-categories -- <category1> <category2> ...");
    process.exit(1);
  }

  const db = initAdmin();
  await db.collection("config").doc("waitlistCategories").set(
    {
      enabledCategories: categories,
      updatedAt: new Date(),
    },
    { merge: true },
  );

  console.log(`config/waitlistCategories set: enabledCategories=${JSON.stringify(categories)}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
