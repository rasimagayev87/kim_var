/**
 * READ-ONLY audit of media that outlived the thing it belonged to.
 *
 * Writes nothing and deletes nothing. Counts, per class, how many
 * Firestore documents and Storage objects are still there after the
 * record that justified them is gone or expired.
 *
 * Run:
 *   npm run audit-orphan-media
 *
 * COST: this lists every object under the media prefixes and reads
 * `stories` in full. At today's scale that is small; on a large bucket
 * it is a real (read-only) bill, so run it deliberately rather than on
 * a schedule.
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

function initAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY in .env.local");
  }
  initializeApp({ credential: cert({ projectId, clientEmail, privateKey }), storageBucket: `${projectId}.firebasestorage.app` });
  return { db: getFirestore(), bucket: getStorage().bucket() };
}

/** `stories/{uid}/{storyId}.jpg` → `storyId`; `_200x200` derivatives
 * resolve to the same id so they are counted with their original. */
function storyIdFromPath(path: string): string | null {
  const m = /^stories\/[^/]+\/([^/.]+?)(_200x200)?\.[^.]+$/.exec(path);
  return m ? m[1] : null;
}

async function main() {
  const { db, bucket } = initAdmin();
  const now = Timestamp.now();

  // ── 1. Stories: expired documents ────────────────────────────────
  const storiesSnap = await db.collection("stories").get();
  let expiredStories = 0;
  let missingExpiresAt = 0;
  const liveStoryIds = new Set<string>();
  for (const doc of storiesSnap.docs) {
    const expiresAt = doc.data().expiresAt as Timestamp | undefined;
    if (!expiresAt) {
      missingExpiresAt++;
      liveStoryIds.add(doc.id);
      continue;
    }
    if (expiresAt.toMillis() < now.toMillis()) expiredStories++;
    else liveStoryIds.add(doc.id);
  }

  // ── 2. Stories: orphan `views` under expired/absent parents ──────
  let viewsUnderExpired = 0;
  for (const doc of storiesSnap.docs) {
    const expiresAt = doc.data().expiresAt as Timestamp | undefined;
    if (expiresAt && expiresAt.toMillis() >= now.toMillis()) continue;
    const views = await doc.ref.collection("views").count().get();
    viewsUnderExpired += views.data().count;
  }

  // ── 3. Storage under stories/ with no live document ──────────────
  const [storyFiles] = await bucket.getFiles({ prefix: "stories/" });
  let orphanStoryObjects = 0;
  let orphanStoryBytes = 0;
  for (const f of storyFiles) {
    const id = storyIdFromPath(f.name);
    if (id && liveStoryIds.has(id)) continue;
    orphanStoryObjects++;
    orphanStoryBytes += Number(f.metadata.size ?? 0);
  }

  // ── 4. Other media prefixes: object counts, for scale ────────────
  const prefixes = ["posts/", "chat_photos/", "chat_videos/", "chat_audio/", "venue_photos/", "offer_photos/", "pinbox_photos/", "event_covers/", "identity_verifications/"];
  const prefixTotals: Record<string, { count: number; bytes: number }> = {};
  for (const prefix of prefixes) {
    const [files] = await bucket.getFiles({ prefix });
    prefixTotals[prefix] = {
      count: files.length,
      bytes: files.reduce((s, f) => s + Number(f.metadata.size ?? 0), 0),
    };
  }

  // ── 5. KYC: reviewed >90d ago but paths still set ────────────────
  const cutoff = Timestamp.fromMillis(Date.now() - 90 * 24 * 60 * 60 * 1000);
  let kycStale = 0;
  for (const status of ["approved", "rejected"] as const) {
    const snap = await db
      .collection("identityVerifications")
      .where("status", "==", status)
      .where("reviewedAt", "<", cutoff)
      .get();
    kycStale += snap.docs.filter((d) => d.data().idFrontPath).length;
  }

  const mb = (b: number) => (b / 1024 / 1024).toFixed(1);

  console.log("\n═══ STORY ═══");
  console.log(`  stories sənədi (cəmi):            ${storiesSnap.size}`);
  console.log(`  müddəti bitmiş, hələ mövcud:      ${expiredStories}`);
  console.log(`  expiresAt sahəsi olmayan:         ${missingExpiresAt}`);
  console.log(`  bitmiş story-lərin altındakı views: ${viewsUnderExpired}`);
  console.log(`  sahibsiz Storage obyekti:         ${orphanStoryObjects}  (${mb(orphanStoryBytes)} MB)`);

  console.log("\n═══ DİGƏR MEDIA PREFİKSLƏRİ (miqyas üçün) ═══");
  for (const [p, t] of Object.entries(prefixTotals)) {
    console.log(`  ${p.padEnd(26)} ${String(t.count).padStart(7)} obyekt  ${mb(t.bytes).padStart(9)} MB`);
  }

  console.log("\n═══ KYC ═══");
  console.log(`  90 gündən köhnə, yolu hələ təyin edilmiş: ${kycStale}`);
  console.log("  (0 gözlənilir — cleanupExpiredIdentityVerificationImages gündəlik işləyir)\n");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
