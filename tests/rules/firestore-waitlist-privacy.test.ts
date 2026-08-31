// Növbə girişində telefon nömrəsi var. Kim oxuya bilir?
//
// Girişdə `phoneNumber`, `partySize`, `note`, `userId` saxlanılır —
// məkan sahibi müştərini çağıra bilsin deyə. Sual budur ki, eyni
// növbədə duran BAŞQA istifadəçilər onu görürmü.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
const OWNER = "wl-owner";
const ALICE = "wl-alice";   // növbədə
const BOB = "wl-bob";       // növbədə
const OUTSIDER = "wl-outsider";
const VENUE = "wl-venue";

before(async () => {
  testEnv = await createTestEnv();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const uid of [OWNER, ALICE, BOB, OUTSIDER]) {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
    }
    await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER, { category: "restaurant" }));
    for (const [id, uid, phone] of [["e-alice", ALICE, "+994501111111"], ["e-bob", BOB, "+994502222222"]]) {
      await setDoc(doc(fs, "venues", VENUE, "waitlist", id), {
        userId: uid, phoneNumber: phone, partySize: 2, status: "waiting", joinedAt: new Date(), queuePosition: 1,
      });
    }
  });
});
after(async () => { await testEnv.cleanup(); });

const entries = (db: ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"] extends never ? never : any) =>
  collection(db, "venues", VENUE, "waitlist");

describe("növbə — telefon nömrəsini kim görür", () => {
  test("məkan sahibi bütün siyahını oxuyur — müştərini çağırmalıdır", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(getDocs(entries(db)));
  });

  test("istifadəçi ÖZ girişini oxuyur", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(getDoc(doc(db, "venues", VENUE, "waitlist", "e-alice")));
    await assertSucceeds(getDocs(query(entries(db), where("userId", "==", ALICE))));
  });

  test("NÖVBƏDƏKİ BAŞQA İSTİFADƏÇİ digərinin girişini oxuya BİLMİR", async () => {
    // Əsas sual budur: Alice növbədədir, Bob-un nömrəsini görürmü.
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDoc(doc(db, "venues", VENUE, "waitlist", "e-bob")));
  });

  test("növbədəki istifadəçi bütün siyahını siyahılaya BİLMİR", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDocs(entries(db)));
  });

  test("başqasının uid-i ilə süzülmüş sorğu da keçmir", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDocs(query(entries(db), where("userId", "==", BOB))));
  });

  test("kənar istifadəçi nə siyahını, nə girişi oxuya bilir", async () => {
    const db = testEnv.authenticatedContext(OUTSIDER).firestore();
    await assertFails(getDocs(entries(db)));
    await assertFails(getDoc(doc(db, "venues", VENUE, "waitlist", "e-alice")));
  });

  test("növbəyə client birbaşa yaza bilmir — yalnız joinWaitlist callable", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, "venues", VENUE, "waitlist", "e-forged"), {
        userId: ALICE, phoneNumber: "+994503333333", partySize: 1, status: "waiting", joinedAt: new Date(),
      }),
    );
  });
});

/**
 * Owner status transitions — what a venue may do to a queue entry.
 *
 * The owner rule constrained the DESTINATION status but not the
 * origin, so a terminal entry could be pushed back to `called`, and
 * `maintainWaitlistQueuePositions` sends "Sıra sizindir! — 5 dəqiqəyə
 * gəlin" on any `!= called` → `called` change. Someone who cancelled
 * and went home could still be summoned.
 *
 * These tests exist because `waitlistCalled` is now UNGATED (see
 * functions/src/notification-categories.ts) — the recipient can no
 * longer switch it off, so the send path has to be the thing that is
 * right.
 */
describe("növbə — sahibin status keçidləri", () => {
  const CANCELLED = "wl-cancelled";
  const NOSHOW = "wl-noshow";
  const SEATED = "wl-seated";
  const WAITING = "wl-waiting2";
  const CALLED = "wl-called2";

  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      const base = { userId: ALICE, partySize: 2, phoneNumber: "+994501234567", joinedAt: new Date() };
      await setDoc(doc(fs, "venues", VENUE, "waitlist", CANCELLED), { ...base, status: "cancelled" });
      await setDoc(doc(fs, "venues", VENUE, "waitlist", NOSHOW), { ...base, status: "noShow" });
      await setDoc(doc(fs, "venues", VENUE, "waitlist", SEATED), { ...base, status: "seated" });
      await setDoc(doc(fs, "venues", VENUE, "waitlist", WAITING), { ...base, status: "waiting" });
      await setDoc(doc(fs, "venues", VENUE, "waitlist", CALLED), { ...base, status: "called" });
    });
  });

  const asOwner = () => testEnv.authenticatedContext(OWNER).firestore();

  test("LƏĞV EDİLMİŞ girişi yenidən `called` etmək RƏDD EDİLİR", async () => {
    // Əsas hal: istifadəçi növbədən çıxıb, evə gedib — ona
    // «5 dəqiqəyə gəlin» bildirişi getməməlidir.
    await assertFails(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", CANCELLED), {
      status: "called", calledAt: new Date(),
    }));
  });

  test("`noShow` girişi yenidən `called` etmək RƏDD EDİLİR", async () => {
    await assertFails(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", NOSHOW), {
      status: "called", calledAt: new Date(),
    }));
  });

  test("`seated` girişi yenidən `called` etmək RƏDD EDİLİR", async () => {
    await assertFails(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", SEATED), {
      status: "called", calledAt: new Date(),
    }));
  });

  test("`noShow` → `waiting` də RƏDD EDİLİR — UI yolu yoxdur, icazə qəsdən verilmir", async () => {
    await assertFails(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", NOSHOW), { status: "waiting" }));
  });

  test("LEGİTİM: `waiting` → `called` işləyir", async () => {
    await assertSucceeds(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", WAITING), {
      status: "called", calledAt: new Date(),
    }));
  });

  test("LEGİTİM: `called` → `seated` işləyir", async () => {
    await assertSucceeds(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", CALLED), {
      status: "seated", seatedAt: new Date(),
    }));
  });

  test("LEGİTİM: `waiting` → `cancelled` (sahibin «Sil» düyməsi) işləyir", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", VENUE, "waitlist", WAITING), {
        userId: ALICE, partySize: 2, phoneNumber: "+994501234567", joinedAt: new Date(), status: "waiting",
      });
    });
    await assertSucceeds(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", WAITING), { status: "cancelled" }));
  });

  test("LEGİTİM: `called` → `noShow` işləyir", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", VENUE, "waitlist", CALLED), {
        userId: ALICE, partySize: 2, phoneNumber: "+994501234567", joinedAt: new Date(), status: "called",
      });
    });
    await assertSucceeds(updateDoc(doc(asOwner(), "venues", VENUE, "waitlist", CALLED), { status: "noShow" }));
  });

  test("KƏNAR istifadəçi heç bir keçid edə bilmir", async () => {
    const db = testEnv.authenticatedContext(OUTSIDER).firestore();
    await assertFails(updateDoc(doc(db, "venues", VENUE, "waitlist", CALLED), { status: "seated" }));
  });
});
