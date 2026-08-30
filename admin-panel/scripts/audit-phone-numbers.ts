/**
 * BACKLOG #8 — READ-ONLY audit: finds stored phone numbers that are not
 * valid E.164.
 *
 * Changes nothing. Its job is to size the problem before anyone decides
 * whether a repair is worth running: the known production case is
 * `+994+994502749898`, a doubled dial code produced by picking a country
 * after typing a full international number (see
 * `_applyDialCodeForCountry`, onboarding_screen.dart — fixed) .
 *
 * Two places store a phone number:
 *   - `users/{uid}/private/data.phoneNumber` — written once at
 *     onboarding, never editable afterwards, so a bad value is permanent
 *     until repaired here.
 *   - `venues/{id}/waitlist/{entry}.phoneNumber` — per queue entry.
 *
 * Deliberately does NOT touch `phoneNumbers/{phone}`: nothing writes to
 * that collection any more (phone sign-in was removed), so it holds no
 * reservations to repair. See BACKLOG for that separate finding.
 *
 * COST: one full read of `users` plus each user's `private/data`
 * document, and a collection-group read of `waitlist`. Small today;
 * check the printed counts before assuming it stays that way.
 *
 * Usage:
 *   npm run audit-phone-numbers
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

/** Kept in sync BY HAND with `normalizePhoneNumber`
 * (functions/src/phone.ts) — `functions/` and `admin-panel/` are
 * separate Node projects with no shared package, the same duplication
 * this codebase already accepts elsewhere. */
const E164 = /^\+\d{8,15}$/;

function classify(raw: unknown): string | null {
  if (typeof raw !== "string" || raw.trim() === "") return "empty";
  const v = raw.trim();
  if (E164.test(v)) return null;
  if (/^(\+\d{1,4})\1\d+$/.test(v.replace(/[\s\-().]/g, ""))) return "doubled-dial-code";
  if (!v.startsWith("+")) return "missing-plus";
  if (/[^\d+]/.test(v)) return "contains-separators-or-letters";
  return "wrong-length";
}

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

/** Masks the middle of a number — this output may end up in a ticket. */
function mask(v: string): string {
  return v.length <= 6 ? "***" : `${v.slice(0, 5)}***${v.slice(-2)}`;
}

async function main() {
  const db = initAdmin();
  const findings: { where: string; id: string; problem: string; masked: string }[] = [];

  const usersSnap = await db.collection("users").get();
  const privateSnaps = await Promise.all(
    usersSnap.docs.map((d) => d.ref.collection("private").doc("data").get()),
  );
  privateSnaps.forEach((snap, i) => {
    const raw = snap.data()?.phoneNumber;
    if (raw === undefined) return; // never onboarded through the phone step
    const problem = classify(raw);
    if (problem) findings.push({ where: "users/private/data", id: usersSnap.docs[i].id, problem, masked: mask(String(raw)) });
  });
  console.log(`users: ${usersSnap.size} sənəd yoxlandı`);

  const waitlistSnap = await db.collectionGroup("waitlist").get();
  for (const doc of waitlistSnap.docs) {
    const problem = classify(doc.get("phoneNumber"));
    if (problem) findings.push({ where: "waitlist", id: doc.ref.path, problem, masked: mask(String(doc.get("phoneNumber"))) });
  }
  console.log(`waitlist: ${waitlistSnap.size} giriş yoxlandı`);

  console.log(`\n${findings.length} pozuq nömrə tapıldı.`);
  for (const f of findings) {
    console.log(`  [${f.problem}] ${f.where}  ${f.id}  ${f.masked}`);
  }
  if (findings.length > 0) {
    console.log(
      "\nHeç nə dəyişdirilmədi. Bu skript yalnız oxuyur — düzəliş Firestore Console-dan əl ilə edilir.",
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Xəta:", error);
    process.exit(1);
  });
