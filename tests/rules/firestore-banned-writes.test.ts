// Self-verification / d4 — banlanmış hesabın hansı yazıları bağlandı.
//
// `isActiveUser()` = `exists(users/{uid}) && !exists(bannedUsers/{uid})`,
// yəni hər yoxlama İKİ əlavə sənəd oxusu deməkdir. Ona görə o, hər
// client-yazılabilir yola tətbiq EDİLMƏYİB — meyar "zərər real, yazma
// tezliyi aşağı" olub. Bu fayl həmin qərarı hər iki istiqamətdə
// qeydə alır: bağlananların bağlı qaldığını, qəsdən açıq
// qalanların isə açıq qaldığını. İkincisi vacibdir — əks halda
// növbəti oxucu onları unudulmuş sayar (səbəblər:
// `docs/ACCEPTED_RISKS.md`).
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, setDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

const OK = "d4-active";
const BANNED = "d4-banned";
const VENUE = "d4-venue";

before(async () => {
  testEnv = await createTestEnv();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    await setDoc(doc(fs, "users", OK), userFixture(OK));
    await setDoc(doc(fs, "users", BANNED), userFixture(BANNED));
    await setDoc(doc(fs, "bannedUsers", BANNED), { bannedAt: new Date() });
    await setDoc(doc(fs, "venues", VENUE), venueFixture(OK, { category: "restaurant" }));
    // Hər iki hesab üçün "oturdulmuş" növbə girişi — rəy yazmaq
    // hüququ. Banlanmış hesabın belə bir girişi ban-dan ƏVVƏLDƏN
    // qala bilər, məhz bu halı yoxlayırıq.
    for (const uid of [OK, BANNED]) {
      await setDoc(doc(fs, "venues", VENUE, "waitlist", `w-${uid}`), { status: "seated", userId: uid });
    }
    await setDoc(doc(fs, "posts", "d4-post"), { userId: OK, caption: "x", authorIsPublic: true });
  });
});

after(async () => {
  await testEnv.cleanup();
});

describe("d4 — BAĞLANAN yollar", () => {
  test("reviews: aktiv hesab yaza bilir", async () => {
    const db = testEnv.authenticatedContext(OK).firestore();
    await assertSucceeds(
      setDoc(doc(db, "reviews", `${VENUE}_${OK}`), {
        venueId: VENUE, userId: OK, rating: 5, comment: "yaxşı",
        waitlistEntryId: `w-${OK}`, createdAt: new Date(), updatedAt: new Date(),
      }),
    );
  });

  test("reviews: banlanmış hesab köhnə ziyarəti ilə də yaza BİLMİR", async () => {
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertFails(
      setDoc(doc(db, "reviews", `${VENUE}_${BANNED}`), {
        venueId: VENUE, userId: BANNED, rating: 1, comment: "qisas",
        waitlistEntryId: `w-${BANNED}`, createdAt: new Date(), updatedAt: new Date(),
      }),
    );
  });

  test("follows: aktiv izləyə bilir, banlanmış BİLMİR", async () => {
    const okDb = testEnv.authenticatedContext(OK).firestore();
    await assertSucceeds(
      setDoc(doc(okDb, "follows", `${OK}_${BANNED}`), {
        followerId: OK, followeeId: BANNED, status: "accepted", createdAt: new Date(),
      }),
    );
    const banDb = testEnv.authenticatedContext(BANNED).firestore();
    await assertFails(
      setDoc(doc(banDb, "follows", `${BANNED}_${OK}`), {
        followerId: BANNED, followeeId: OK, status: "accepted", createdAt: new Date(),
      }),
    );
  });

  test("activeCheckins: banlanmış hesab check-in edə BİLMİR", async () => {
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertFails(setDoc(doc(db, "venues", VENUE, "activeCheckins", BANNED), { createdAt: new Date() }));
  });

  test("activeCheckins: aktiv hesab edə bilir", async () => {
    const db = testEnv.authenticatedContext(OK).firestore();
    await assertSucceeds(setDoc(doc(db, "venues", VENUE, "activeCheckins", OK), { createdAt: new Date() }));
  });

  test("activeCheckins: check-in halında banlanan hesab ÇIXA bilir", async () => {
    // Silmə qəsdən qorunmayıb — əks halda ban zamanı içəridə olan
    // adam məkanın canlı sayında ilişib qalardı.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", VENUE, "activeCheckins", BANNED), { createdAt: new Date() });
    });
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertSucceeds(deleteDoc(doc(db, "venues", VENUE, "activeCheckins", BANNED)));
  });

  test("chats: banlanmış hesab söhbət sənədi yarada BİLMİR", async () => {
    // `messages` C-3-dən bəri qorunurdu, valideyn sənəd yox — yarımçıq
    // tətbiqin özü. Banlanmış hesab boş da olsa qurbanın söhbət
    // siyahısında peyda ola bilirdi.
    const ids = [BANNED, OK].sort();
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertFails(
      setDoc(doc(db, "chats", `${ids[0]}_${ids[1]}`), {
        participants: ids, initiatorId: BANNED, status: "accepted", createdAt: new Date(),
      }),
    );
  });
});

describe("d4 — QƏSDƏN açıq qalan yollar (xərc qərarı)", () => {
  // Bunlar sınıq deyil. `ACCEPTED_RISKS.md`-də fərdi olaraq
  // sadalanıblar; test onların səssizcə dəyişməməsi üçündür.
  test("supportMessages: banlanmış hesab dəstəyə yaza BİLİR (qəsdən)", async () => {
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertSucceeds(
      setDoc(doc(db, "supportMessages", "d4-support"), {
        uid: BANNED, message: "hesabım bağlandı, səbəbini bilmək istəyirəm",
      }),
    );
  });

  test("posts/likes: banlanmış hesab bəyənə BİLİR (qəsdən — sayğac səs-küyü)", async () => {
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertSucceeds(setDoc(doc(db, "posts", "d4-post", "likes", BANNED), {}));
    await assertSucceeds(deleteDoc(doc(db, "posts", "d4-post", "likes", BANNED)));
  });
});

describe("d4 — `private/data.banned` güzgüsü client-dən qorunur", () => {
  // Güzgü Kəşf et süzgəcinin oxuduğu yeganə sahədir. Sahib öz private
  // sənədinin demək olar hər sahəsini yaza bilir, ona görə bu bir
  // sətir olmasa banlanmış hesab sadəcə bayrağı silib geri qayıdardı.
  test("sahib `banned` yaza BİLMİR", async () => {
    const db = testEnv.authenticatedContext(OK).firestore();
    await assertFails(
      setDoc(doc(db, "users", OK, "private", "data"), { banned: false }, { merge: true }),
    );
  });

  test("banlanmış hesab öz bayrağını silə BİLMİR", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users", BANNED, "private", "data"), { banned: true }, { merge: true });
    });
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertFails(
      setDoc(doc(db, "users", BANNED, "private", "data"), { banned: false }, { merge: true }),
    );
  });

  test("digər private sahələr həmişəki kimi yazıla bilir", async () => {
    const db = testEnv.authenticatedContext(OK).firestore();
    await assertSucceeds(
      setDoc(doc(db, "users", OK, "private", "data"), { lat: 40.4093, lng: 49.8671 }, { merge: true }),
    );
  });
});
