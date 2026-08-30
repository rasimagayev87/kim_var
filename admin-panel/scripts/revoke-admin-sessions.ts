/**
 * P0 / C-2 — one-off: revokes every admin/moderator's Firebase refresh
 * tokens, invalidating any session minted from a leaked
 * `?emergencyToken=` link.
 *
 * WHY THIS IS NEEDED AT ALL
 * Deleting the emergency sign-in path (see `src/app/login/page.tsx`)
 * stops NEW tokens from being minted, but it does nothing about
 * sessions already created from one. A Firebase custom token is not
 * single-use, and exchanging it yields a refresh token that outlives
 * the custom token's own hour — so a token that leaked into Cloud
 * Logging could still be backing a live admin session right now.
 * `revokeRefreshTokens` is what actually severs those.
 *
 * WHY IT TAKES EFFECT IMMEDIATELY
 * Both admin-panel verification points already pass `checkRevoked:
 * true` — `getCurrentAdmin` (src/lib/auth/server.ts, every page and
 * Server Action) and Proxy's own `/login` branch. Without that this
 * script would be a no-op until each `__session` cookie expired on its
 * own (up to 5 days).
 *
 * ORDERING — READ BEFORE RUNNING
 * Run this only AFTER the C-2 code change is deployed. Running it
 * first would sign every admin out while the old login page is still
 * live, which leaves the emergency path as the most convenient way
 * back in — the exact opposite of the intent.
 *
 * EFFECT ON PEOPLE
 * Every admin/moderator is signed out and must sign in again with
 * e-mail + password. Nothing else about their account changes: no role,
 * claim, or `admins/{uid}` document is touched.
 *
 * Usage (dry run first — prints who would be affected, changes nothing):
 *   npm run revoke-admin-sessions
 *   npm run revoke-admin-sessions -- --confirm
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

function initAdmin() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    console.error(
      "Firebase Admin SDK credentials tapılmadı — .env.local faylında FIREBASE_PROJECT_ID, " +
        "FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY doldurulmalıdır (bax: .env.local.example).",
    );
    process.exit(1);
  }

  return initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
}

async function main() {
  const confirmed = process.argv.includes("--confirm");
  const app = initAdmin();
  const auth = getAuth(app);
  const db = getFirestore(app);

  // `admins/{uid}` is the roster the panel itself lists from. It is
  // deliberately NOT the source of truth for authorization (the custom
  // claim is) — but it IS the only way to enumerate "who is an admin"
  // without walking every Auth user, which is exactly why it exists.
  // Each uid's live claim is re-read below so a stale roster row can't
  // cause a pointless revoke, and so a genuine mismatch is surfaced
  // rather than silently ignored.
  const rosterSnap = await db.collection("admins").get();
  if (rosterSnap.empty) {
    console.error("admins kolleksiyası boşdur — heç nə edilmədi. Roster-in doğruluğunu yoxlayın.");
    process.exit(1);
  }

  console.log(`${rosterSnap.size} admin/moderator qeydi tapıldı.\n`);

  let revoked = 0;
  let skipped = 0;

  for (const docSnap of rosterSnap.docs) {
    const uid = docSnap.id;
    let email = "(naməlum)";
    let claimRole: string | undefined;
    try {
      const user = await auth.getUser(uid);
      email = user.email ?? "(e-poçtsuz)";
      claimRole = (user.customClaims as { role?: string } | undefined)?.role;
    } catch {
      console.log(`  ATLANDI  ${uid} — Auth hesabı tapılmadı (roster qeydi köhnəlib).`);
      skipped++;
      continue;
    }

    if (claimRole !== "admin" && claimRole !== "moderator") {
      console.log(`  ATLANDI  ${email} (${uid}) — canlı claim yoxdur (roster: ${docSnap.data()?.role ?? "?"}).`);
      skipped++;
      continue;
    }

    if (!confirmed) {
      console.log(`  [DRY RUN] ${email} (${uid}, ${claimRole}) — sessiyaları ləğv EDİLƏCƏK.`);
      revoked++;
      continue;
    }

    await auth.revokeRefreshTokens(uid);
    console.log(`  LƏĞV EDİLDİ ${email} (${uid}, ${claimRole})`);
    revoked++;
  }

  console.log(
    `\n${confirmed ? "Ləğv edildi" : "Ləğv ediləcək"}: ${revoked}, atlandı: ${skipped}.`,
  );
  if (!confirmed) {
    console.log("\nHeç bir dəyişiklik edilmədi. Həqiqətən icra etmək üçün:");
    console.log("  npm run revoke-admin-sessions -- --confirm");
  } else {
    console.log("\nBütün adminlər yenidən e-poçt + parol ilə daxil olmalıdır.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Xəta:", error);
    process.exit(1);
  });
