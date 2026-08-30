/**
 * One-off backfill for the `users/{uid}/private/data.banned` mirror.
 *
 * `setUserBanned` writes the mirror alongside the `bannedUsers/{uid}`
 * tombstone from now on, but accounts banned BEFORE that change have a
 * tombstone and no mirror. The consequence is narrow and worth stating
 * exactly: those accounts are still fully banned — every rule and
 * callable enforces the ban from the tombstone — they just are not
 * filtered out of the Discover and nearby candidate lists, which is
 * the one thing the mirror is read for.
 *
 * NOT AUTOMATED ON PURPOSE. Run it once, deliberately, after the
 * `setUserBanned` change is deployed. Running it before would let a
 * subsequent unban clear the tombstone while leaving a mirror behind,
 * which is the one drift direction that is actually harmful (an
 * unbanned account invisible in Discover with nothing explaining why).
 *
 * Dry run (default) prints what it would write and changes NOTHING:
 *   npm run backfill-banned-mirror
 * Apply:
 *   npm run backfill-banned-mirror -- --confirm
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

function initAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");
  if (!projectId || !clientEmail || !privateKey) {
    console.error("Firebase Admin SDK credentials tapılmadı — .env.local yoxlanılmalıdır.");
    process.exit(1);
  }
  return getFirestore(initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) }));
}

async function main() {
  const confirm = process.argv.includes("--confirm");
  const db = initAdmin();

  const tombstones = await db.collection("bannedUsers").get();
  console.log(`bannedUsers: ${tombstones.size} tombstone`);
  if (tombstones.empty) return;

  const needed: string[] = [];
  for (const doc of tombstones.docs) {
    const privateRef = db.collection("users").doc(doc.id).collection("private").doc("data");
    const snap = await privateRef.get();
    if (!snap.exists) {
      // The account's own documents are gone but the tombstone is not.
      // Not this script's problem to fix — reported so it is visible.
      console.log(`  [private/data YOXDUR] ${doc.id} — güzgü yazılmır`);
      continue;
    }
    if (snap.data()?.banned === true) continue;
    needed.push(doc.id);
  }

  console.log(`\nGüzgüsü çatışmayan: ${needed.length}`);
  for (const uid of needed) console.log(`  ${uid}`);

  if (!confirm) {
    console.log("\nDRY RUN — heç nə yazılmadı. Tətbiq üçün: --confirm");
    return;
  }

  const batch = db.batch();
  for (const uid of needed) {
    batch.set(db.collection("users").doc(uid).collection("private").doc("data"), { banned: true }, { merge: true });
  }
  await batch.commit();
  console.log(`\n${needed.length} güzgü yazıldı.`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Xəta:", error);
    process.exit(1);
  });
