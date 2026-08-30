// P0 / H-6 — `usernames` enumerasiyasının bağlanması.
//
// RT-25 `users` üzərində `list`-i bağladı, amma `usernames` tam
// `username → uid` indeksidir və listable qalmışdı: bir `orderBy(
// documentId).startAt([''])` + səhifələmə bütün istifadəçi bazasını
// verirdi. `get` isə deep link üçün QƏSDƏN açıq qalır — sərhəd
// "bir bilinən username-i aç" ilə "hamısını sadala" arasındadır.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, limit, orderBy, query, setDoc, startAt } from "firebase/firestore";
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
