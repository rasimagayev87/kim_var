/**
 * TEMPORARY emergency-access tool — mints a Firebase custom token for
 * an EXISTING admin/moderator account and prints a one-time sign-in
 * link, entirely bypassing the Email+Password provider.
 *
 * Why this exists: Identity Platform's Email+Password provider is
 * currently returning a project-wide 503 "Error code: 47" on BOTH
 * signIn and signUp for this project (confirmed via direct REST calls
 * against a completely fresh throwaway account, so it isn't
 * account-specific) — an open Firebase Support ticket tracks the real
 * fix. Custom-token minting/exchange goes through a different code
 * path and was confirmed still working on this same project. This
 * script is the stopgap until Support resolves the Email+Password
 * outage — delete it once that's fixed, it has no reason to exist
 * afterward.
 *
 * Refuses to mint for anything that isn't already a real admin/
 * moderator (checked against BOTH the custom claim and the
 * `admins/{uid}` roster doc) — this must never become a way to grant
 * access, only a way to work around one broken sign-in provider for
 * someone who already has it.
 *
 * The token is a bearer credential good for the full hour it's valid
 * (Firebase custom tokens are always 1-hour, non-configurable) — share
 * the link only with the admin it's for, the same care as a password
 * reset link.
 *
 * Usage:
 *   npm run mint-emergency-token -- <email>
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

const ADMIN_PANEL_ORIGIN = "https://admin.peakpin.app";

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
  const [email] = process.argv.slice(2);
  if (!email) {
    console.error("İstifadə: npm run mint-emergency-token -- <email>");
    process.exit(1);
  }

  const app = initAdmin();
  const auth = getAuth(app);
  const db = getFirestore(app);

  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch {
    console.error(`Xəta: "${email}" ünvanı ilə heç bir Auth hesabı tapılmadı.`);
    process.exit(1);
  }

  const claimRole = (user.customClaims as { role?: string } | undefined)?.role;
  const rosterDoc = await db.collection("admins").doc(user.uid).get();
  const rosterRole = rosterDoc.exists ? (rosterDoc.data()?.role as string | undefined) : undefined;
  const role = claimRole ?? rosterRole;

  if (role !== "admin" && role !== "moderator") {
    console.error(
      `Xəta: "${email}" (${user.uid}) admin/moderator deyil (claim: ${claimRole ?? "yoxdur"}, ` +
        `admins/{uid}: ${rosterRole ?? "yoxdur"}) — bu skript YALNIZ artıq admin olan hesablar üçündür.`,
    );
    process.exit(1);
  }

  const token = await auth.createCustomToken(user.uid);
  const link = `${ADMIN_PANEL_ORIGIN}/login?emergencyToken=${encodeURIComponent(token)}`;

  console.log(`"${email}" (${role}) üçün müvəqqəti giriş linki yaradıldı — 1 saat etibarlıdır:\n`);
  console.log(link);
  console.log("\nBu linki YALNIZ bu hesabın sahibinə göndər — parol sıfırlama linki qədər həssasdır.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Xəta:", error);
    process.exit(1);
  });
