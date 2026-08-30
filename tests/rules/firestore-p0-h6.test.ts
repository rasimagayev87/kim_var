// P0 / H-6 — `usernames` enumerasiyasının bağlanması.
//
// RT-25 `users` üzərində `list`-i bağladı, amma `usernames` tam
// `username → uid` indeksidir və listable qalmışdı: bir `orderBy(
// documentId).startAt([''])` + səhifələmə bütün istifadəçi bazasını
// verirdi. `get` isə deep link üçün QƏSDƏN açıq qalır — sərhəd
// "bir bilinən username-i aç" ilə "hamısını sadala" arasındadır.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, limit, orderBy, query, setDoc, startAt, where } from "firebase/firestore";
import { createTestEnv } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const [name, uid] of [["alice", "p0h6-alice"], ["albert", "p0h6-albert"], ["bob", "p0h6-bob"]]) {
      await setDoc(doc(fs, "usernames", name), { uid, createdAt: new Date() });
    }
  });
});

after(async () => {
  await testEnv.cleanup();
});

describe("P0 / H-6 — usernames list bağlıdır, get açıqdır", () => {
  test("bütün kolleksiyanı sadalamaq RƏDD EDİLİR (daxil olmuş istifadəçi)", async () => {
    const db = testEnv.authenticatedContext("p0h6-scraper").firestore();
    await assertFails(getDocs(collection(db, "usernames")));
    await assertFails(getDocs(query(collection(db, "usernames"), limit(1000))));
  });

  test("prefiks sorğusu da RƏDD EDİLİR (köhnə client sorğusunun forması)", async () => {
    const db = testEnv.authenticatedContext("p0h6-scraper").firestore();
    await assertFails(
      getDocs(query(collection(db, "usernames"), orderBy("__name__"), startAt("al"), limit(20))),
    );
  });

  test("imzasız sadalamaq da RƏDD EDİLİR", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDocs(query(collection(db, "usernames"), limit(10))));
  });

  test("TƏK sənədin get-i daxil olmuş istifadəçi üçün İŞLƏYİR", async () => {
    const db = testEnv.authenticatedContext("p0h6-reader").firestore();
    await assertSucceeds(getDoc(doc(db, "usernames", "alice")));
  });

  test("TƏK sənədin get-i İMZASIZ da işləyir (deep link — qəsdən açıq)", async () => {
    // `deep_link_handler.dart:_openProfileByUsername` daxil olmamış
    // istifadəçi üçün də işləməlidir — ACCEPTED_RISKS.md-də sənədləşib.
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "usernames", "alice")));
  });

  test("mövcud olmayan username-in get-i də icazəlidir (mövcudluq yoxlaması)", async () => {
    const db = testEnv.authenticatedContext("p0h6-reader").firestore();
    await assertSucceeds(getDoc(doc(db, "usernames", "heckim-yoxdur")));
  });
});

// ---------------------------------------------------------------------------
// P0 / M-7 — `reviews` üzərində `list` bağlanması.
//
// Rəy yalnız `hasVerifiedVisit` arxasında yarana bilər (məkanın öz
// personalının `seated` işarələdiyi növbə girişi), yəni onun MÖVCUDLUĞU
// müəllifin həmin məkanda FİZİKİ olduğunun sübutudur. Sənəd id-si
// `{venueId}_{userId}` olduğu üçün açıq `list` bütün "kim harada olub"
// qrafını verirdi — Prompt 4-ün lokasiya feed-indən sildiyi məlumatın
// eynisi, başqa yoldan.
// ---------------------------------------------------------------------------
describe("P0 / M-7 — reviews list bağlıdır, get açıqdır", () => {
  const REVIEWER = "m7-reviewer";
  const VIEWER = "m7-viewer";
  const VENUE = "m7-venue";

  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, "reviews", `${VENUE}_${REVIEWER}`), {
        venueId: VENUE,
        userId: REVIEWER,
        rating: 5,
        comment: "əla",
        waitlistEntryId: "w1",
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
  });

  test("bütün kolleksiyanı sadalamaq RƏDD EDİLİR", async () => {
    const db = testEnv.authenticatedContext(VIEWER).firestore();
    await assertFails(getDocs(collection(db, "reviews")));
  });

  test("venueId üzrə filtrlə sadalamaq da RƏDD EDİLİR (məkan-məkan gəzmə)", async () => {
    // Dinamik `import()` fərqli modul nüsxəsi qaytarır və Firestore
    // "Type does not match the expected instance" verir — top-level
    // idxal istifadə olunur.
    const db = testEnv.authenticatedContext(VIEWER).firestore();
    await assertFails(getDocs(query(collection(db, "reviews"), where("venueId", "==", VENUE), limit(50))));
  });

  test("TƏK rəyin get-i işləyir (watchMyReview — .doc() oxuması)", async () => {
    const db = testEnv.authenticatedContext(REVIEWER).firestore();
    await assertSucceeds(getDoc(doc(db, "reviews", `${VENUE}_${REVIEWER}`)));
  });

  test("başqasının rəyinin get-i də işləyir (id bilinirsə enumerasiya deyil)", async () => {
    const db = testEnv.authenticatedContext(VIEWER).firestore();
    await assertSucceeds(getDoc(doc(db, "reviews", `${VENUE}_${REVIEWER}`)));
  });
});
