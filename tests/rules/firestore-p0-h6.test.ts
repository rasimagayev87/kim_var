// P0 / H-6 — `usernames` enumerasiyasının bağlanması.
//
// RT-25 `users` üzərində `list`-i bağladı, amma `usernames` tam
// `username → uid` indeksidir və listable qalmışdı: bir `orderBy(
// documentId).startAt([''])` + səhifələmə bütün istifadəçi bazasını
// verirdi. `get` isə deep link üçün QƏSDƏN açıq qalır — sərhəd
// "bir bilinən username-i aç" ilə "hamısını sadala" arasındadır.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, limit, orderBy, query, setDoc, startAt, updateDoc, where } from "firebase/firestore";
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

/**
 * A4-H1 / nameLower — the identity fields on `users/{uid}` itself.
 *
 * H-6 closed enumeration of the `usernames` LEDGER. It did not connect
 * that ledger to the `username` field the app actually RENDERS, so a
 * reservation could be skipped entirely: `users/{uid}.username` was
 * plain free text. Every @handle surface reads that field
 * (`buildPublicCandidatePayload`/`buildSearchProfilePayload`, the
 * profile screen, the share card), so a handle held by someone else —
 * or one `isReservedUsername` exists to forbid, like 'support' — could
 * simply be typed in.
 *
 * `nameLower` is the same class one field over: it is what
 * `searchUsersByName` range-scans, and nothing tied it to the
 * `firstName`/`lastName` a viewer sees.
 */
describe("A4-H1 — users.username rezervasiyaya bağlıdır", () => {
  const HOLDER = "p0h6-alice";      // 'alice' rezervasiyasının sahibi
  const ATTACKER = "a4h1-attacker";

  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      for (const uid of [HOLDER, ATTACKER]) {
        await setDoc(doc(fs, "users", uid), {
          uid, username: `user_${uid}`, firstName: "Ad", lastName: "Soyad",
          nameLower: "ad soyad", accountPrivacy: "public", businessStatus: "active",
          bio: "", createdAt: new Date(),
        });
      }
      await setDoc(doc(fs, "usernames", `user_${ATTACKER}`), { uid: ATTACKER, createdAt: new Date() });
    });
  });

  test("BAŞQASININ rezerv etdiyi handle-ı yazmaq RƏDD EDİLİR", async () => {
    // 'alice' HOLDER-in rezervasiyasıdır.
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "users", ATTACKER), { username: "alice" }));
  });

  test("HEÇ KİMİN rezerv etmədiyi handle-ı yazmaq da RƏDD EDİLİR", async () => {
    // Rezervasiyasız handle — ledger-də sənəd yoxdur, `exists()` false.
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "users", ATTACKER), { username: "tamamile_bos_ad" }));
  });

  test("`isReservedUsername` blocklist-i artıq bu yolla da keçilə bilmir", async () => {
    // Əvvəl blocklist yalnız ledger-i qoruyurdu; profil sahəsi açıq
    // olduğu üçün @support kimi görünmək mümkün idi.
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    for (const reserved of ["support", "admin", "peakpin"]) {
      await assertFails(updateDoc(doc(db, "users", ATTACKER), { username: reserved }));
    }
  });

  test("ÖZ rezervasiyasını yazmaq İŞLƏYİR — mövcud axın pozulmur", async () => {
    // `updateUsername` əvvəlcə `usernames/{lower}`-i tutur, sonra bu
    // sahəni yazır. Mağazadakı build məhz bunu edir.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "usernames", "yeni_ad"), { uid: ATTACKER, createdAt: new Date() });
    });
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", ATTACKER), { username: "yeni_ad" }));
  });

  test("böyük/kiçik hərf: ledger id-si kiçik, göstərilən dəyər original qala bilər", () => {
    // `updateUsername` `newLower`-i rezerv edir, `normalizedNew`-i yazır.
    return (async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "usernames", "mixedcase"), { uid: ATTACKER, createdAt: new Date() });
      });
      const db = testEnv.authenticatedContext(ATTACKER).firestore();
      await assertSucceeds(updateDoc(doc(db, "users", ATTACKER), { username: "MixedCase" }));
    })();
  });

  test("username-ə TOXUNMAYAN redaktə əlavə oxu ödəmir və keçir", async () => {
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", ATTACKER), { bio: "yeni bio" }));
  });
});

describe("A4 — users.nameLower göstərilən adla uzlaşmalıdır", () => {
  const U = "a4nl-user";

  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users", U), {
        uid: U, username: `user_${U}`, firstName: "Ad", lastName: "Soyad",
        nameLower: "ad soyad", accountPrivacy: "public", businessStatus: "active",
        bio: "", createdAt: new Date(),
      });
      await setDoc(doc(ctx.firestore(), "usernames", `user_${U}`), { uid: U, createdAt: new Date() });
    });
  });

  test("axtarış açarını göstərilən addan AYIRMAQ rədd edilir", async () => {
    // Profilində "Ad Soyad" yazan hesab "elvin memmedov" axtarışında
    // çıxa bilməməlidir.
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), { nameLower: "elvin memmedov" }));
  });

  test("adı dəyişmədən nameLower-i dəyişmək rədd edilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), { nameLower: "" }));
  });

  test("ad DƏYİŞƏNDƏ uyğun nameLower ilə birlikdə keçir — client-in mövcud batch-i", async () => {
    // `ProfileController.save` üçü də bir batch-də yazır; ifadə
    // Dart tərəfdəki `'$firstName $lastName'.trim().toLowerCase()`
    // ilə eynidir.
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", U), {
      firstName: "Elvin", lastName: "Məmmədov", nameLower: "elvin məmmədov",
    }));
  });

  test("uyğunsuz cütlük rədd edilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), {
      firstName: "Rəşad", lastName: "Əliyev", nameLower: "basqa adam",
    }));
  });

  test("boş soyad: trim() nəzərə alınır", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", U), {
      firstName: "Tək", lastName: "", nameLower: "tək",
    }));
  });
});
