/**
 * One-off repair: writes the missing public-offer acceptance record for
 * a venue that paid on a RETRY.
 *
 * WHY IT IS NEEDED. `submitVenue` attaches the acceptance to the first
 * payment; `applyPaymentOutcome` promotes it into the venue's permanent
 * record only when a charge succeeds. Until 2026-08-31,
 * `retryVenueCreationPayment` created a fresh payment WITHOUT carrying
 * the acceptance forward — so an owner whose first attempt failed ended
 * up with a paid, approved venue and no record that they ever accepted
 * the offer. Clause 3.2 requires that record. The code path is fixed;
 * this repairs the venue it already happened to.
 *
 * WHERE THE DATA COMES FROM. Nothing is invented. The acceptance is
 * read off the SUPERSEDED/FAILED payment doc that carried it, and
 * `acceptedAt` is the moment the owner actually accepted — the
 * `acceptedAt` inside that stored acceptance, falling back to the
 * payment's `createdAt`. NOT `now()`: this is a legal record of when
 * someone agreed to something, and stamping it with the repair date
 * would make it false.
 *
 * Dry run (default) prints the exact writes and changes nothing:
 *   npm run backfill-offer-acceptance
 * Apply:
 *   npm run backfill-offer-acceptance -- --confirm
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

interface StoredAcceptance {
  version?: string;
  documentUrl?: string;
  appVersion?: string;
  platform?: string;
  acceptedAt?: Timestamp;
}

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
  let repaired = 0;

  for (const venueDoc of venues.docs) {
    const venue = venueDoc.data();
    if (venue.offerAcceptedVersion) continue; // already on file

    const existing = await venueDoc.ref.collection("offerAcceptances").limit(1).get();
    if (!existing.empty) continue;

    // Every payment for this venue, newest first — the acceptance may
    // sit on any of them, typically the superseded first attempt.
    const payments = await db
      .collection("payments")
      .where("listingId", "==", venueDoc.id)
      .get();

    const withAcceptance = payments.docs
      .filter((d) => d.get("type") === "venue_subscription" && d.get("pendingOfferAcceptance"))
      .sort((a, b) => {
        const at = (a.get("createdAt") as Timestamp | undefined)?.toMillis() ?? 0;
        const bt = (b.get("createdAt") as Timestamp | undefined)?.toMillis() ?? 0;
        return at - bt;
      });

    const completed = payments.docs.find(
      (d) => d.get("type") === "venue_subscription" && d.get("status") === "completed",
    );

    console.log(`\nvenues/${venueDoc.id}  "${venue.name}"  status=${venue.status}`);
    if (!completed) {
      console.log("  ATLANILIR — bu məkan üçün tamamlanmış abunə ödənişi yoxdur.");
      continue;
    }
    if (withAcceptance.length === 0) {
      console.log("  ATLANILIR — heç bir ödəniş sənədində saxlanmış qəbul yoxdur, bərpa ediləcək məlumat yoxdur.");
      continue;
    }

    const source = withAcceptance[0];
    const acceptance = source.get("pendingOfferAcceptance") as StoredAcceptance;
    const acceptedAt =
      acceptance.acceptedAt ?? (source.get("createdAt") as Timestamp | undefined) ?? null;

    if (!acceptance.version || !acceptance.documentUrl || !acceptedAt) {
      console.log("  ATLANILIR — saxlanmış qəbul natamamdır, uydurmuram.");
      continue;
    }

    console.log(`  mənbə ödəniş: ${source.id} (status=${source.get("status")})`);
    console.log(`  version=${acceptance.version}  platform=${acceptance.platform}  appVersion=${acceptance.appVersion}`);
    console.log(`  acceptedAt=${acceptedAt.toDate().toISOString()}  ← FAKTİKİ qəbul vaxtı, bugünkü tarix DEYİL`);
    console.log(`  yazılacaq: venues/${venueDoc.id} sahələri + offerAcceptances/{yeni}`);

    if (confirm) {
      const batch = db.batch();
      batch.update(venueDoc.ref, {
        offerAcceptedVersion: acceptance.version,
        offerAcceptedAt: acceptedAt,
        offerAcceptedFrom: `${acceptance.appVersion} / ${acceptance.platform}`,
        offerDocumentUrl: acceptance.documentUrl,
      });
      batch.set(venueDoc.ref.collection("offerAcceptances").doc(), {
        version: acceptance.version,
        documentUrl: acceptance.documentUrl,
        appVersion: acceptance.appVersion ?? null,
        platform: acceptance.platform ?? null,
        acceptedAt,
        paymentId: completed.id,
        backfilledAt: Timestamp.now(),
        backfillReason: "retryVenueCreationPayment did not carry the acceptance forward",
      });
      await batch.commit();
      console.log("  YAZILDI");
    }
    repaired++;
  }

  console.log(`\n${repaired} məkan ${confirm ? "bərpa edildi" : "bərpa ediləcək"}.`);
  if (!confirm) console.log("DRY RUN — heç nə yazılmadı. Tətbiq üçün: -- --confirm");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("Xəta:", e.message);
    process.exit(1);
  });
