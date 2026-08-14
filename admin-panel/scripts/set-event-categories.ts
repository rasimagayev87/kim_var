/**
 * Sets `config/eventCategories.enabledCategories` in Firestore — the
 * list of `VenueCategory` names allowed to publish `venueEvents` (see
 * `eventCategoryConfigProvider` in
 * lib/features/events/presentation/providers/venue_event_providers.dart).
 * A venue whose category isn't in this list never sees the "Tədbirlər"
 * create button, though any events it published before a category
 * change stays visible/manageable.
 *
 * Run this by hand whenever the eligible category list changes:
 *   npm run set-event-categories -- restaurant pub fastFood cinema nightClub kidsEntertainment
 *
 * Category names must match `VenueCategory` enum values exactly (see
 * lib/features/venues/domain/entities/venue.dart) — e.g. "fastFood",
 * not "fast_food" or "Fast-Food".
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
    console.error("Usage: npm run set-event-categories -- <category1> <category2> ...");
    process.exit(1);
  }

  const db = initAdmin();
  await db.collection("config").doc("eventCategories").set(
    {
      enabledCategories: categories,
      updatedAt: new Date(),
    },
    { merge: true },
  );

  console.log(`config/eventCategories set: enabledCategories=${JSON.stringify(categories)}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
