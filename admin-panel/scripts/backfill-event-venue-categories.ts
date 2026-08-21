/**
 * One-off migration: sets `venueCategory` on every `venueEvents` doc
 * that predates that field (see `VenueEvent`'s own doc comment on why
 * it exists — the Fürsətlər filter sheet's category chip is a
 * `VenueCategory`, not the event's own `VenueEventCategory`, and
 * couldn't filter events at all until this field existed).
 *
 * Reads each event's `venueId`, looks up that venue's `category`
 * (cached per venueId since many events share a venue), and writes it
 * as `venueCategory`. An event whose venue no longer exists is left
 * alone — it already decodes as `VenueCategory.other` client-side (see
 * `VenueCategoryConverter`'s `orElse`), same as it did before this
 * migration ran.
 *
 * Safe to re-run: only touches docs that still lack the field.
 *
 * Usage:
 *   npm run backfill-event-venue-categories
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

  const snap = await db.collection("venueEvents").get();
  const missing = snap.docs.filter((doc) => !("venueCategory" in doc.data()));

  if (missing.length === 0) {
    console.log("No venueEvents missing venueCategory — nothing to do.");
    return;
  }

  const venueCategoryCache = new Map<string, string | null>();
  async function categoryFor(venueId: string): Promise<string | null> {
    if (venueCategoryCache.has(venueId)) return venueCategoryCache.get(venueId)!;
    const venueSnap = await db.collection("venues").doc(venueId).get();
    const category = (venueSnap.data()?.category as string | undefined) ?? null;
    venueCategoryCache.set(venueId, category);
    return category;
  }

  let batch = db.batch();
  let opsInBatch = 0;
  let total = 0;
  let skipped = 0;

  for (const doc of missing) {
    const venueId = doc.data().venueId as string | undefined;
    const category = venueId ? await categoryFor(venueId) : null;
    if (!category) {
      skipped++;
      continue;
    }

    batch.update(doc.ref, { venueCategory: category });
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

  console.log(`Backfilled venueCategory on ${total} event(s)${skipped > 0 ? `, skipped ${skipped} (venue not found)` : ""}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
