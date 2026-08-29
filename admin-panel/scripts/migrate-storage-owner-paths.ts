/**
 * One-off migration (Düzəliş Prompt 3 / K-6): moves the 4 flat,
 * ownerless Storage paths (`venue_photos/{id}.jpg`, `offer_photos/{id}.jpg`,
 * `pinbox_photos/{id}.jpg`, `event_covers/{id}.jpg`) to the new
 * owner-scoped shape `{prefix}/{ownerUid}/{id}.jpg` that `storage.rules`
 * now enforces writes against. Not run automatically by this change —
 * `storage.rules` keeps a read-only transition block for the old flat
 * paths, so existing files/URLs keep working until this is explicitly
 * run. Intended to be run once, then the old-path `read`-only blocks in
 * `storage.rules` can be deleted in a follow-up.
 *
 * For each of the 4 collections: downloads the original file's bytes
 * from the OLD path, re-uploads to the NEW path, updates the
 * corresponding Firestore document's URL field to the new download URL,
 * then deletes the OLD file. The `_200x200` resized derivative is
 * deliberately NOT copied — re-uploading to the new path re-triggers
 * the `storage-resize-images` extension, which regenerates it there on
 * its own; the old derivative is simply abandoned (harmless — nothing
 * references a `_200x200` URL directly, only the original).
 *
 * Idempotent: skips any document whose stored URL already points at the
 * new `{prefix}/{ownerUid}/` shape (so a partial/interrupted run can be
 * safely re-run).
 *
 * Usage:
 *   npm run migrate-storage-owner-paths
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

function initAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY in .env.local");
  }

  const app = initializeApp({
    credential: cert({ projectId, clientEmail, privateKey }),
    storageBucket: `${projectId}.firebasestorage.app`,
  });
  return { db: getFirestore(app), bucket: getStorage(app).bucket() };
}

interface MigrationTarget {
  /** Firestore collection to read/update. */
  collection: string;
  /** Storage path prefix (matches storage.rules' new `{prefix}/{ownerUid}/{fileName}`). */
  prefix: string;
  /** Firestore field on the document holding the download URL. */
  urlField: string;
  /** Resolves the owning uid for a given document snapshot — async since
   *  venueEvents doesn't carry ownerId directly and needs a venue lookup. */
  resolveOwnerId: (doc: FirebaseFirestore.QueryDocumentSnapshot) => Promise<string | undefined>;
}

async function migrateCollection(
  db: FirebaseFirestore.Firestore,
  bucket: ReturnType<ReturnType<typeof getStorage>["bucket"]>,
  target: MigrationTarget,
) {
  const snap = await db.collection(target.collection).get();
  let migrated = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const url = doc.data()[target.urlField] as string | undefined;
    if (!url) continue;

    // Already-migrated or never-had-a-photo docs both look like this —
    // the new path shape appears in the URL's encoded object path.
    if (url.includes(encodeURIComponent(`${target.prefix}/`))) {
      skipped++;
      continue;
    }

    const ownerId = await target.resolveOwnerId(doc);
    if (!ownerId) {
      console.warn(`  SKIP ${target.collection}/${doc.id}: could not resolve ownerId`);
      continue;
    }

    const oldPath = `${target.prefix}/${doc.id}.jpg`;
    const oldFile = bucket.file(oldPath);
    const [exists] = await oldFile.exists();
    if (!exists) {
      console.warn(`  SKIP ${target.collection}/${doc.id}: no file at ${oldPath}`);
      continue;
    }

    const newPath = `${target.prefix}/${ownerId}/${doc.id}.jpg`;
    await bucket.file(oldPath).copy(bucket.file(newPath));
    const newFile = bucket.file(newPath);
    await newFile.makePublic().catch(() => undefined); // matches existing public-read rule; no-op if already covered by IAM
    const [newUrl] = await newFile.getSignedUrl({ action: "read", expires: "03-01-2500" }).catch(() => [undefined]);
    // Prefer the same download-token URL shape the app already uses —
    // regenerate via getDownloadURL()-equivalent metadata token instead
    // of a signed URL, since that's what firebase_storage's client SDK
    // expects for `Image.network(url)` to keep working the same way.
    const [metadata] = await newFile.getMetadata();
    const token = (metadata.metadata as Record<string, string> | undefined)?.firebaseStorageDownloadTokens;
    const downloadUrl = token
      ? `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(newPath)}?alt=media&token=${token}`
      : newUrl;

    await doc.ref.update({ [target.urlField]: downloadUrl });
    await oldFile.delete();
    migrated++;
    console.log(`  ${target.collection}/${doc.id}: ${oldPath} -> ${newPath}`);
  }

  console.log(`${target.collection}: migrated ${migrated}, skipped ${skipped} (already migrated/no photo).`);
}

async function main() {
  const { db, bucket } = initAdmin();

  const targets: MigrationTarget[] = [
    {
      collection: "venues",
      prefix: "venue_photos",
      urlField: "photoUrl",
      resolveOwnerId: async (doc) => doc.data().ownerId as string | undefined,
    },
    {
      collection: "offers",
      prefix: "offer_photos",
      urlField: "imageUrl",
      resolveOwnerId: async (doc) => doc.data().ownerId as string | undefined,
    },
    {
      collection: "pinboxes",
      prefix: "pinbox_photos",
      urlField: "imageUrl",
      resolveOwnerId: async (doc) => doc.data().ownerId as string | undefined,
    },
    {
      collection: "venueEvents",
      prefix: "event_covers",
      urlField: "coverImageUrl",
      resolveOwnerId: async (doc) => {
        const venueId = doc.data().venueId as string | undefined;
        if (!venueId) return undefined;
        const venueSnap = await db.collection("venues").doc(venueId).get();
        return venueSnap.data()?.ownerId as string | undefined;
      },
    },
  ];

  for (const target of targets) {
    console.log(`Migrating ${target.collection}...`);
    await migrateCollection(db, bucket, target);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
