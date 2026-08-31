/**
 * One-off cleanup of the venue-creation test data from 2026-08-31.
 *
 * NOT part of any automated flow. Written to be read before it is run.
 *
 * WHAT IT DELETES
 *   - `payments` documents whose status is `failed` (no money moved)
 *   - everything under `venue_photos/` in Storage
 *
 * WHY THAT IS SAFE RIGHT NOW: the `venues` collection is empty, so
 * every one of those photos and payments points at a venue that no
 * longer exists. The script re-checks that itself and REFUSES to run
 * if any venue exists — it is only correct while the collection is
 * empty, and it should not be repurposed later without rethinking it.
 *
 * A `pending` payment is skipped rather than deleted: it could still
 * be an open Epoint order, and deleting the record while Epoint may
 * still call the webhook would leave `applyPaymentOutcome` looking up
 * a document that is gone.
 *
 * Dry run (default) — prints, changes nothing:
 *   npm run cleanup-test-venues
 * Apply:
 *   npm run cleanup-test-venues -- --confirm
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

async function main() {
  const confirm = process.argv.includes("--confirm");
  const app = initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID!,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL!,
      privateKey: process.env.FIREBASE_PRIVATE_KEY!.replace(/\\n/g, "\n"),
    }),
    storageBucket: "kim-var-73ce9.firebasestorage.app",
  });
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket();

  const venues = await db.collection("venues").get();
  if (!venues.empty) {
    console.error(`DAYANDIM — ${venues.size} məkan var. Bu skript yalnız kolleksiya boş olanda doğrudur.`);
    process.exit(1);
  }
  console.log("venues: 0 — bütün aşağıdakılar orphandır.\n");

  const pays = await db.collection("payments").get();
  console.log(`payments: ${pays.size}`);
  for (const d of pays.docs) {
    const x = d.data();
    if (x.status !== "failed") {
      console.log(`  ATLANILIR (${x.status}): ${d.id} — açıq Epoint sifarişi ola bilər`);
      continue;
    }
    console.log(`  ${confirm ? "silinir" : "silinəcək"}: ${d.id}  ${x.amount} AZN  listing=${x.listingId}`);
    if (confirm) await d.ref.delete();
  }

  const [files] = await bucket.getFiles({ prefix: "venue_photos/" });
  console.log(`\nvenue_photos: ${files.length} fayl`);
  for (const f of files) {
    console.log(`  ${confirm ? "silinir" : "silinəcək"}: ${f.name}`);
    if (confirm) await f.delete();
  }

  if (!confirm) {
    console.log("\nDRY RUN — heç nə silinmədi. Tətbiq üçün: -- --confirm");
    return;
  }
  console.log("\n── yekun ──");
  console.log("  payments:", (await db.collection("payments").get()).size);
  console.log("  venue_photos:", (await bucket.getFiles({ prefix: "venue_photos/" }))[0].length);
}

main().then(() => process.exit(0)).catch((e) => { console.error("XƏTA:", e.message); process.exit(1); });
