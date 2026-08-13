/**
 * Sets `config/legal.currentTermsVersion`/`currentPrivacyVersion` in
 * Firestore — the version every signed-in user's own `users/{uid}
 * .consent.termsVersion`/`privacyVersion` gets compared against on
 * Home mount (see `consent_dialog.dart`'s doc comment). Bumping this
 * past what a user last accepted is what makes the blocking re-consent
 * dialog appear for them.
 *
 * Run this by hand whenever terms-of-service.html or privacy-policy.html
 * changes materially — bump BOTH the "Versiya: X.Y" line on the actual
 * document (peakpin-landing/public/, mirrored to kim_var/legal/) and
 * `kCurrentTermsVersion`/`kCurrentPrivacyVersion` in
 * lib/features/legal/legal_versions.dart to the same number first, then
 * run this script last so the re-consent check has something new to
 * compare against.
 *
 * Usage:
 *   npm run set-legal-version -- <termsVersion> <privacyVersion>
 *   npm run set-legal-version -- 1.0 1.0
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
  const [termsVersion, privacyVersion] = process.argv.slice(2);
  if (!termsVersion || !privacyVersion) {
    console.error("Usage: npm run set-legal-version -- <termsVersion> <privacyVersion>");
    process.exit(1);
  }

  const db = initAdmin();
  await db.collection("config").doc("legal").set(
    {
      currentTermsVersion: termsVersion,
      currentPrivacyVersion: privacyVersion,
      updatedAt: new Date(),
    },
    { merge: true },
  );

  console.log(`config/legal set: currentTermsVersion=${termsVersion}, currentPrivacyVersion=${privacyVersion}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
