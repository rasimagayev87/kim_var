/**
 * Düzəliş Prompt 6 / K-10, PAY-34 — diaqnostik sorğu, YALNIZ OXUYUR,
 * HEÇ NƏ YAZMIR. Ölçür ki, bu tətbiqin köhnə (bu promptdan ƏVVƏLKİ)
 * kodunda PAY-5-in paralel-webhook (TOCTOU) zərəri nə qədər real
 * sənəddə iz qoyub.
 *
 * `status:"failed"` + `epointTransaction` mövcud olması normal
 * ssenaridə mümkün deyil — `epointTransaction` yalnız uğurlu ödəniş
 * budağında yazılır (bax `applyPaymentOutcome`, functions/src/index.ts).
 * Bu kombinasiyanın mövcudluğu məhz iki paralel webhook-un (biri uğur,
 * biri rədd) eyni sənədə yarışdığının, və sonuncu (rədd) yazının əvvəlki
 * uğur yazısının `epointTransaction` sahəsini silmədiyinin izidir — yəni
 * pul HƏQİQƏTƏN tutulub, amma sənəd "uğursuz" kimi qalıb.
 *
 * Bu sorğunun nəticəsi = neçə real ödənişin bu tarixi bug-dan
 * təsirləndiyinin dəqiq ölçüsü. Nəticəyə görə addım: hər bir tapılan
 * sənəd əl ilə araşdırılmalı (Epoint-in öz panelində `epointTransaction`
 * ID-si axtarılıb real ödənişin taleyi yoxlanılmalı) — bu skript özü
 * heç bir düzəliş YAZMIR, yalnız siyahını çıxarır.
 *
 * Usage (YALNIZ istifadəçinin öz təsdiqi ilə işə salınsın):
 *   npm run count-orphan-payments
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

  const app = initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
  return getFirestore(app);
}

async function main() {
  const db = initAdmin();

  const failedSnap = await db.collection("payments").where("status", "==", "failed").get();
  const withTransaction = failedSnap.docs.filter((d) => d.data().epointTransaction != null);

  console.log(`status=failed sənəd sayı: ${failedSnap.size}`);
  console.log(`bunlardan epointTransaction mövcud olan (real pul tutulmuş ola bilər — TOCTOU izi): ${withTransaction.length}`);

  if (withTransaction.length > 0) {
    console.log("\nƏl ilə araşdırma üçün siyahı (paymentId, epointTransaction, amount, listingType/listingId):");
    for (const doc of withTransaction) {
      const data = doc.data();
      console.log(
        `  ${doc.id}  |  ${data.epointTransaction}  |  ${data.amount} ${data.currency ?? "AZN"}  |  ${data.listingType}/${data.listingId}`,
      );
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
