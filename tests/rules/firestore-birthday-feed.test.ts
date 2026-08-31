/**
 * `users/{uid}/birthdayFeed/{dateKey}` — the server-side filter behind
 * the "Ad günü fürsətləri" section.
 *
 * The requirement was that only people whose birthday it is see that
 * section, and that the decision is made on the server. There is no
 * "is it my birthday" boolean anywhere for a client to flip: the
 * section renders when this document exists, `publishBirthdayCampaigns`
 * is the only thing that writes one, and nobody can create their own.
 *
 * These three tests are the whole enforcement, so they are worth
 * stating plainly: the owner reads, a stranger cannot, and no client
 * writes.
 */
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

let env: RulesTestEnvironment;
const CELEBRANT = "bf-celebrant";
const STRANGER = "bf-stranger";
const TODAY = "2026-08-31";

before(async () => {
  env = await createTestEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const u of [CELEBRANT, STRANGER]) await setDoc(doc(fs, "users", u), userFixture(u));
    // Written the way the server writes it — Admin SDK, rules bypassed.
    await setDoc(doc(fs, "users", CELEBRANT, "birthdayFeed", TODAY), {
      date: TODAY,
      venueIds: ["v1", "v2", "v3"],
      highlightVenueIds: ["v1", "v2", "v3"],
      notifiedAt: new Date(),
      expiresAt: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
    });
  });
});
after(async () => { await env.cleanup(); });

describe("birthdayFeed — oxuma", () => {
  test("sahib öz ad günü siyahısını oxuyur", async () => {
    const db = env.authenticatedContext(CELEBRANT).firestore();
    await assertSucceeds(getDoc(doc(db, "users", CELEBRANT, "birthdayFeed", TODAY)));
  });

  test("başqası oxuya bilmir — kimin ad günü olduğu sızmır", async () => {
    // This is the privacy half. `birthDate` lives in
    // `users/{uid}/private/data`; a readable feed document would put
    // the same fact back in the open, one day a year, for anyone who
    // guessed today's date key.
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(getDoc(doc(db, "users", CELEBRANT, "birthdayFeed", TODAY)));
  });

  test("anonim oxuya bilmir", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "users", CELEBRANT, "birthdayFeed", TODAY)));
  });
});

describe("birthdayFeed — yazma heç kimə açıq deyil", () => {
  test("istifadəçi özünə ad günü siyahısı yarada bilmir", async () => {
    // The one that matters: if this succeeded, anyone could switch on
    // their own "Ad günü fürsətləri" section on any day, which is
    // exactly the client-side check this design replaced.
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(
      setDoc(doc(db, "users", STRANGER, "birthdayFeed", TODAY), {
        date: TODAY,
        venueIds: ["v1"],
      }),
    );
  });

  test("sahib öz siyahısını dəyişə bilmir", async () => {
    const db = env.authenticatedContext(CELEBRANT).firestore();
    await assertFails(
      updateDoc(doc(db, "users", CELEBRANT, "birthdayFeed", TODAY), { venueIds: ["hacked"] }),
    );
  });

  test("sahib öz siyahısını silə bilmir — TTL silir", async () => {
    const db = env.authenticatedContext(CELEBRANT).firestore();
    await assertFails(deleteDoc(doc(db, "users", CELEBRANT, "birthdayFeed", TODAY)));
  });

  test("başqası özgə siyahısına yaza bilmir", async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(
      setDoc(doc(db, "users", CELEBRANT, "birthdayFeed", TODAY), { venueIds: ["x"] }),
    );
  });
});
