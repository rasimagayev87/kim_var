/**
 * One-off migration (Düzəliş Prompt 4 / K-1): splits every `users/{uid}`
 * document's PII/sensitive fields off into a new owner-only
 * `users/{uid}/private/data` subdocument — see `privateDataRef` in
 * `functions/src/index.ts` for the exhaustive field-by-field reasoning
 * of what moved and what deliberately stayed public.
 *
 * For each `users/{uid}` doc: reads the fields in PRIVATE_FIELDS off
 * the main doc, writes whichever of them are actually present to
 * `private/data`, then deletes both PRIVATE_FIELDS and DEAD_FIELDS
 * (ölü sahələr — no remaining writer, confirmed by exhaustive grep;
 * deleted outright, never migrated) from the main doc via a single
 * batched pair of writes per user.
 *
 * Idempotent: a user whose `private/data` doc already exists is
 * skipped entirely — a partially-completed or re-run migration never
 * double-writes or clobbers a field the previous run (or
 * `completeOnboarding`, for a user who signed up after this script
 * started running) already wrote correctly.
 *
 * NOT run automatically by this change — this repo's `firestore.rules`/
 * `functions/src/index.ts` already assume the split going forward
 * (new signups via `completeOnboarding` already write the split shape),
 * but existing users need this script run once, explicitly, before any
 * of the moved fields can be considered fully migrated.
 *
 * Usage:
 *   npm run migrate-users-private-data
 */
import { cert, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

function initAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY in .env.local");
  }

  const app = initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
  return getFirestore(app);
}

// Kept in sync with `privateDataRef`'s own doc comment in
// functions/src/index.ts — the full set of fields moving to
// `users/{uid}/private/data`. Deliberately EXCLUDES `country`,
// `blockedUsers`, `reportedCount`, `birthdayOffersOptIn`,
// `premiumExpiresAt` — all five stay public (top-level `.where()`
// query dependencies / Düzəliş Prompt 12 finding, see that same doc
// comment for the full reasoning of each).
const PRIVATE_FIELDS = [
  "email",
  "phoneNumber",
  "birthDate",
  "gender",
  "city",
  "consent",
  "discoverRadiusMode",
  "discoverRadiusKm",
  "visibilityRadiusMode",
  "visibilityRadiusKm",
  "showReadReceipts",
  "twoFactorEnabled",
  "ghostModeEnabled",
  "incognitoBrowsingEnabled",
  "notificationPreferences",
  "mapLocationSettings",
  "activeChatId",
  "activeCheckinVenueId",
  "lastVisitorsCheckedAt",
  "loginProvider",
  "appVersion",
  "buildNumber",
  "platform",
  "osVersion",
  "lastSeenAt",
  "fcmTokens",
  "knownDeviceSignatures",
  "lat",
  "lng",
] as const;

// No remaining writer anywhere in the codebase (confirmed by
// exhaustive grep across lib/ and functions/src/index.ts) — deleted
// outright, never migrated to `private/data`.
const DEAD_FIELDS = ["friendCount", "eventCount", "isVerified", "starCount", "heartCount", "dislikeCount"] as const;

async function main() {
  const db = initAdmin();
  const snap = await db.collection("users").get();

  let migrated = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const privateRef = doc.ref.collection("private").doc("data");
    const privateSnap = await privateRef.get();
    if (privateSnap.exists) {
      skipped++;
      continue;
    }

    const data = doc.data();
    const privatePatch: Record<string, unknown> = {};
    for (const field of PRIVATE_FIELDS) {
      if (data[field] !== undefined) privatePatch[field] = data[field];
    }

    const mainDeletePatch: Record<string, unknown> = {};
    for (const field of [...PRIVATE_FIELDS, ...DEAD_FIELDS]) {
      if (data[field] !== undefined) mainDeletePatch[field] = FieldValue.delete();
    }

    const batch = db.batch();
    batch.set(privateRef, privatePatch);
    if (Object.keys(mainDeletePatch).length > 0) {
      batch.update(doc.ref, mainDeletePatch);
    }
    await batch.commit();

    migrated++;
    console.log(`  migrated users/${doc.id}`);
  }

  console.log(`Done: migrated ${migrated}, skipped ${skipped} (already migrated).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
