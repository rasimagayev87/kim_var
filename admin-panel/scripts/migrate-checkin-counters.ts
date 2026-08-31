/**
 * One-off migration: moves the raw check-in counter off the public
 * venue document.
 *
 * BEFORE: `venues/{id}.activeCheckinCount` — the exact number of people
 * checked in, on a document any signed-in user can read.
 *
 * AFTER:
 *   `venues/{id}/private/counters.activeCheckinCount`  — raw, server-only
 *   `venues/{id}.visibleCheckinCount`                  — same number, floored
 *
 * The floor is `VENUE_AUDIENCE_MIN_REPORTABLE_COUNT` (5): below it the
 * public field reads 0. "1 nəfər burada" identifies a specific person
 * to anyone who knows who is nearby, and hiding that in the widget
 * while the true number sat in a readable document would have been
 * decoration rather than privacy.
 *
 * The count is RECOUNTED from the `activeCheckins` subcollection rather
 * than copied from the old field — if the old counter had drifted,
 * copying would carry the drift forward, and the subcollection is the
 * actual truth.
 *
 * `activeCheckinCount` is left on the venue document on purpose. Old
 * app builds still read it; removing it would make their counter
 * vanish, whereas leaving it makes them show a number that simply
 * stops moving. Delete it once the store build has rolled over — see
 * docs/BACKLOG.md.
 *
 * Dry run (default), changes nothing:
 *   npm run migrate-checkin-counters
 * Apply:
 *   npm run migrate-checkin-counters -- --confirm
 */
import { cert, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

/** Must match `VENUE_AUDIENCE_MIN_REPORTABLE_COUNT` in functions/src/geo.ts. */
const MIN_REPORTABLE = 5;

async function main() {
  const confirm = process.argv.includes("--confirm");
  const db = getFirestore(
    initializeApp({
      credential: cert({
        projectId: process.env.FIREBASE_PROJECT_ID!,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL!,
        privateKey: process.env.FIREBASE_PRIVATE_KEY!.replace(/\\n/g, "\n"),
      }),
    }),
  );

  const venues = await db.collection("venues").get();
  console.log(`venues: ${venues.size}\n`);

  for (const venueDoc of venues.docs) {
    const stored = (venueDoc.get("activeCheckinCount") as number | undefined) ?? 0;
    const actual = (await venueDoc.ref.collection("activeCheckins").count().get()).data().count;
    const visible = actual < MIN_REPORTABLE ? 0 : actual;

    const drift = actual !== stored ? `  ⚠️ DRIFT (köhnə sahə: ${stored})` : "";
    console.log(`  ${venueDoc.id}  "${venueDoc.get("name")}"`);
    console.log(`    faktiki check-in: ${actual}${drift}`);
    console.log(`    private/counters.activeCheckinCount = ${actual}`);
    console.log(`    visibleCheckinCount = ${visible}${actual > 0 && visible === 0 ? "  (hədddən aşağı)" : ""}`);

    if (confirm) {
      const batch = db.batch();
      batch.set(
        venueDoc.ref.collection("private").doc("counters"),
        { activeCheckinCount: actual, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      batch.update(venueDoc.ref, { visibleCheckinCount: visible });
      await batch.commit();
      console.log("    YAZILDI");
    }
  }

  if (!confirm) console.log("\nDRY RUN — heç nə yazılmadı. Tətbiq üçün: -- --confirm");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("Xəta:", e.message);
    process.exit(1);
  });
