/**
 * READ-ONLY doğrulama — 1.4 (UTC/yerli sürüşmə).
 * Heç nə yazmır. Yalnız birthDate timestamp-larının UTC saatını sayır.
 */
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const db = (() => {
  initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID!,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL!,
      privateKey: process.env.FIREBASE_PRIVATE_KEY!.replace(/\\n/g, "\n"),
    }),
  });
  const fs = getFirestore();
  // gRPC bu mühitdən keçmir (ETIMEDOUT) — REST-ə keç.
  fs.settings({ preferRest: true });
  return fs;
})();

async function main() {
  const users = await db.collection("users").select().get();
  console.log(`users sənədi: ${users.size}`);

  let withBirthDate = 0;
  const byUtcHour = new Map<string, number>();
  const samples: string[] = [];

  for (const doc of users.docs) {
    const snap = await doc.ref.collection("private").doc("data").get();
    const bd = snap.data()?.birthDate as Timestamp | undefined;
    if (!bd) continue;
    withBirthDate++;
    const d = bd.toDate();
    const utc = `${String(d.getUTCHours()).padStart(2, "0")}:${String(d.getUTCMinutes()).padStart(2, "0")}`;
    byUtcHour.set(utc, (byUtcHour.get(utc) ?? 0) + 1);

    const bakuDay = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Baku", year: "numeric", month: "2-digit", day: "2-digit",
    }).format(d);
    const utcDay = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`;
    if (samples.length < 10) {
      samples.push(`  UTC saat ${utc} | UTC gün ${utcDay} | Bakı günü ${bakuDay} | ${utcDay === bakuDay ? "eyni" : "★ SÜRÜŞMƏ"}`);
    }
  }

  console.log(`birthDate olan: ${withBirthDate}`);
  console.log("UTC saat paylanması:", [...byUtcHour.entries()].sort());
  console.log("Nümunələr:");
  samples.forEach((s) => console.log(s));
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
