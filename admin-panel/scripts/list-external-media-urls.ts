/**
 * P0 / H-5 — READ-ONLY audit: lists every stored media URL that does
 * NOT point at this project's own Firebase Storage bucket.
 *
 * Deletes nothing, changes nothing. Its whole job is to answer "does
 * closing this actually break any existing document?" with data instead
 * of a guess, before the corresponding `firestore.rules` restriction
 * and Cloud Function checks start rejecting new writes.
 *
 * WHY THESE FIELDS
 * `users.photoUrl`, `venues.photoUrl`, `offers.imageUrl`,
 * `pinboxes.imageUrl`, `venueEvents.coverImageUrl`, `posts.mediaUrl`
 * and `stories.mediaUrl` were all accepted as arbitrary strings. Every
 * one of them is rendered with `NetworkImage`/`Image.network` on other
 * users' devices, so an external URL turns any viewer into a request to
 * a server the author controls — an IP/User-Agent collector aimed at
 * whoever happens to see the profile or listing. It also defeats
 * moderation outright: a moderator approves the bytes at a URL, and the
 * author swaps those bytes afterwards with no Firestore write at all,
 * so nothing re-enters review.
 *
 * COST
 * One full read of each collection listed below. Run it against a
 * quiet period, and note the document counts it prints — at present
 * these collections are small, but this is a `.get()` per collection,
 * not an aggregate.
 *
 * Usage:
 *   npm run list-external-media-urls
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const BUCKET = "kim-var-73ce9.firebasestorage.app";
const ALLOWED_PREFIX = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/`;

/** Collections and the URL-bearing field on each. */
const TARGETS: { collection: string; field: string }[] = [
  { collection: "users", field: "photoUrl" },
  { collection: "venues", field: "photoUrl" },
  { collection: "offers", field: "imageUrl" },
  { collection: "pinboxes", field: "imageUrl" },
  { collection: "venueEvents", field: "coverImageUrl" },
  { collection: "posts", field: "mediaUrl" },
  { collection: "stories", field: "mediaUrl" },
];

function initAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");
  if (!projectId || !clientEmail || !privateKey) {
    console.error("Firebase Admin SDK credentials tapılmadı — .env.local yoxlanılmalıdır.");
    process.exit(1);
  }
  return initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
}

async function main() {
  const db = getFirestore(initAdmin());
  let totalDocs = 0;
  let totalExternal = 0;

  for (const { collection, field } of TARGETS) {
    const snap = await db.collection(collection).select(field).get();
    totalDocs += snap.size;

    const external: { id: string; url: string }[] = [];
    for (const doc of snap.docs) {
      const url = doc.get(field);
      // Absent/null is normal (no photo yet) — only a present, non-empty
      // string that points somewhere else is a finding.
      if (typeof url !== "string" || url.length === 0) continue;
      if (url.startsWith(ALLOWED_PREFIX)) continue;
      external.push({ id: doc.id, url });
    }

    totalExternal += external.length;
    const status = external.length === 0 ? "TƏMİZ" : `${external.length} XARİCİ`;
    console.log(`${collection}.${field}: ${snap.size} sənəd — ${status}`);
    for (const row of external) {
      // Truncated: these are attacker-chosen strings and this output may
      // end up pasted into a ticket or a terminal that renders them.
      const shown = row.url.length > 120 ? `${row.url.slice(0, 120)}…` : row.url;
      console.log(`    ${row.id}  ${JSON.stringify(shown)}`);
    }
  }

  console.log(`\nCəmi ${totalDocs} sənəd yoxlandı, ${totalExternal} xarici URL tapıldı.`);
  if (totalExternal === 0) {
    console.log("Heç bir mövcud sənəd yeni məhdudiyyətdən təsirlənmir.");
  } else {
    console.log(
      "Bu sənədlər YENİ yazılarda rədd ediləcək, amma MÖVCUD dəyərləri olduğu kimi qalır " +
        "(qaydalar yalnız yazını yoxlayır). Hər birinə əl ilə baxılmalıdır — heç nə avtomatik silinmir.",
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Xəta:", error);
    process.exit(1);
  });
