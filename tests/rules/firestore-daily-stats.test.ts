/**
 * `venues/{id}/dailyStats/{date}` — closed to every client.
 *
 * Including the venue's OWN owner. The reporting screen does not exist
 * yet, so there is no read this rule needs to permit; opening it now
 * would grant access to a schema nobody has reviewed for that purpose.
 * When the screen is built, that is a separate, deliberate decision.
 */
import { after, before, describe, test } from "node:test";
import { assertFails, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let env: RulesTestEnvironment;
const OWNER = "ds-owner";
const OTHER = "ds-other";
const VENUE = "ds-venue";
const DATE = "2026-09-01";

before(async () => {
  env = await createTestEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const u of [OWNER, OTHER]) await setDoc(doc(fs, "users", u), userFixture(u));
    await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER, { category: "restaurant" }));
    await setDoc(doc(fs, "venues", VENUE, "dailyStats", DATE), {
      date: DATE, audienceAvg: 12, audiencePeak: 30, checkins: 8, likes: 3,
    });
  });
});
after(async () => { await env.cleanup(); });

describe("dailyStats — oxu bağlıdır", () => {
  test("MƏKAN SAHİBİ də oxuya bilmir", async () => {
    // Qəsdən. Hesabat ekranı yoxdur, yəni icazə veriləcək heç bir
    // real oxu yoxdur; ekran gələndə icazə ayrıca qərar veriləcək.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(getDoc(doc(db, "venues", VENUE, "dailyStats", DATE)));
  });

  test("başqası oxuya bilmir", async () => {
    const db = env.authenticatedContext(OTHER).firestore();
    await assertFails(getDoc(doc(db, "venues", VENUE, "dailyStats", DATE)));
  });

  test("anonim oxuya bilmir", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "venues", VENUE, "dailyStats", DATE)));
  });
});

describe("dailyStats — yazı bağlıdır", () => {
  test("sahib rəqəmləri dəyişə bilmir", async () => {
    // Hesabat abunənin dəyərini göstərmək üçündür; sahibin öz
    // rəqəmlərini yaza bilməsi onu mənasız edərdi.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venues", VENUE, "dailyStats", DATE), { audiencePeak: 9999 }));
  });

  test("sahib yeni gün yarada bilmir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(setDoc(doc(db, "venues", VENUE, "dailyStats", "2026-09-02"), { date: "2026-09-02" }));
  });

  test("sahib silə bilmir — TTL silir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(deleteDoc(doc(db, "venues", VENUE, "dailyStats", DATE)));
  });

  test("başqası yaza bilmir", async () => {
    const db = env.authenticatedContext(OTHER).firestore();
    await assertFails(setDoc(doc(db, "venues", VENUE, "dailyStats", DATE), { audiencePeak: 1 }));
  });
});

describe("private/counters — sayğaclar da bağlıdır", () => {
  test("sahib check-in tallisini oxuya bilmir", async () => {
    // `checkinsByDay` və `audienceToday` XAM saylardır — k-həddi
    // yalnız hesabat anında tətbiq olunur, ona görə mənbə bağlı
    // qalmalıdır.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(getDoc(doc(db, "venues", VENUE, "private", "counters")));
  });
});
