/**
 * Düzəliş Prompt 7 / H #196 — sets `config/iapTesters.testerUids` in
 * Firestore: the PeakPin `uid` allowlist `verifyInAppPurchase`
 * (functions/src/index.ts) checks before honoring an Apple Sandbox
 * transaction in production. A Sandbox receipt is free to obtain with
 * any Apple Sandbox test account, so without this allowlist any uid
 * could claim VIP through it — this ties "who's allowed sandbox" to
 * the PeakPin account itself, independent of which Apple ID was used
 * to test with. Android has no equivalent (Google Play's
 * `subscriptionsv2` API has no sandbox/test distinction to check — see
 * `verifyInAppPurchase`'s own doc comment).
 *
 * Run this by hand whenever the tester list changes:
 *   npm run set-iap-testers -- uid1 uid2 uid3
 *
 * uids are your own PeakPin account uids (Firebase Auth), NOT Apple
 * Sandbox tester emails — find yours in Firebase Console → Authentication,
 * or in the admin panel's user detail page.
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
  const testerUids = process.argv.slice(2);
  if (testerUids.length === 0) {
    console.error("Usage: npm run set-iap-testers -- <uid1> <uid2> ...");
    process.exit(1);
  }

  const db = initAdmin();
  await db.collection("config").doc("iapTesters").set(
    {
      testerUids,
      updatedAt: new Date(),
    },
    { merge: true },
  );

  console.log(`config/iapTesters set: testerUids=${JSON.stringify(testerUids)}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
