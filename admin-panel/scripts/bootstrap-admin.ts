/**
 * One-time CLI script to create (or promote) an admin/moderator
 * account by setting its `role` custom claim directly via the Admin
 * SDK — the same trust boundary every other claim-setting path in
 * this app uses (see src/lib/auth/session.ts's doc comments), just
 * run by hand instead of through a screen, since there's no signed-in
 * admin yet to click a button the first time.
 *
 * Usage:
 *   npm run bootstrap-admin -- <email> <password> [admin|moderator]
 *
 * Now that the "Admin idarəetməsi" screen exists, use that for every
 * admin AFTER the first one — this script stays around only for
 * standing up the very first admin (nobody can click a button yet) or
 * recovering a locked-out project (e.g. every admin account got
 * deleted).
 *
 * Also upserts the `admins/{uid}` roster doc (see firestore.rules'
 * doc comment on that collection) — otherwise an admin bootstrapped
 * this way would have a working custom claim but never show up in the
 * "Admin idarəetməsi" list, which reads from that collection, not
 * Auth directly.
 *
 * Deliberately does NOT import src/lib/firebase/admin.ts — that file
 * is guarded with `import "server-only"`, which only resolves to a
 * no-op under Next's own bundler (via its `react-server` export
 * condition); run through plain tsx/Node like this script is, it
 * always throws. A CLI script is inherently server-only by what it
 * is, so it gets its own small Admin SDK init instead.
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
  const [email, password, roleArg] = process.argv.slice(2);
  const role = roleArg === "moderator" ? "moderator" : "admin";

  if (!email || !password) {
    console.error("İstifadə: npm run bootstrap-admin -- <email> <parol> [admin|moderator]");
    process.exit(1);
  }
  if (password.length < 6) {
    console.error("Parol ən azı 6 simvol olmalıdır (Firebase Auth tələbi).");
    process.exit(1);
  }

  const app = initAdmin();
  const auth = getAuth(app);
  const db = getFirestore(app);

  let uid: string;
  try {
    const existing = await auth.getUserByEmail(email);
    uid = existing.uid;
    console.log(`Mövcud istifadəçi tapıldı: ${email} (${uid}) — rol təyin edilir...`);
  } catch {
    const created = await auth.createUser({ email, password, emailVerified: true });
    uid = created.uid;
    console.log(`Yeni admin hesabı yaradıldı: ${email} (${uid})`);
  }

  await auth.setCustomUserClaims(uid, { role });
  await db.collection("admins").doc(uid).set({
    email: email.toLowerCase(),
    role,
    addedAt: new Date(),
    addedBy: "bootstrap-script",
  });
  console.log(`✓ "${email}" hesabına "${role}" rolu təyin edildi.`);
  console.log(
    "Qeyd: bu hesabla artıq açıq sessiya varsa, dəyişiklik üçün yenidən daxil olmaq lazımdır " +
      "(ID token-lər custom claim-ləri yalnız yeniləndikdə daşıyır).",
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Xəta:", error);
    process.exit(1);
  });
