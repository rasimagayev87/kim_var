/**
 * Düzəliş Prompt 10 / H #181 — sets `config/businessOffer` in
 * Firestore: the canonical "current PeakPin Biznes Xidmətlərinin
 * Publik Ofertası" version/URL that `submitVenue`/
 * `retryVenueSubscriptionPayment` (functions/src/index.ts) now read
 * server-side instead of trusting whatever version/URL a client claims
 * a venue owner accepted — see `currentBusinessOffer`'s own doc
 * comment there. Same shape/reasoning as `set-waitlist-categories.ts`.
 *
 * Run this by hand whenever the offer PDF changes materially:
 *   npm run set-business-offer-version -- 1.1 https://peakpin.app/legal/business-offer-v1.1.pdf
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
  const [currentVersion, documentUrl] = process.argv.slice(2);
  if (!currentVersion || !documentUrl) {
    console.error("Usage: npm run set-business-offer-version -- <version> <documentUrl>");
    process.exit(1);
  }

  const db = initAdmin();
  await db.collection("config").doc("businessOffer").set(
    {
      currentVersion,
      documentUrl,
      updatedAt: new Date(),
    },
    { merge: true },
  );

  console.log(`config/businessOffer set: currentVersion=${currentVersion} documentUrl=${documentUrl}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
