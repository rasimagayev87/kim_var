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
describe("A4-H1 — users.username və nameLower KLİENTDƏN yazıla bilmir", () => {
  // Bu blok əvvəllər `usernameOwnedByCaller()` + `nameLowerMatchesName()`
  // şərtli icazələrini yoxlayırdı: klient `usernames` rezervasiyasını
  // tutubsa `username` yaza bilirdi, `nameLower` göstərilən adla
  // uzlaşırsa keçirdi.
  //
  // Hər ikisi GETDİ, zəiflədilmədi. `nameLowerMatchesName()` işləyə
  // bilmirdi: Firestore Rules-un `.lower()`-i yalnız ASCII-dir, Dart-ın
  // `toLowerCase()`-i tam Unicode, ona görə Ə/İ/Ş/Ç/Ö/Ü/Ğ daşıyan hər ad
  // rədd olunurdu və sahibi öz profilini redaktə edə bilmirdi.
  //
  // Bu faylın köhnə versiyası bunu tutmadı, çünki hər nümunəsi ("Ad
  // Soyad", "Tək") ASCII idi. Yeni `profile-identity.test.ts` məhz o
  // hərfləri saxlayır.
  //
  // İndi dörd sahə də `touchesLockedUserFields()`-dədir və yeganə yazıcı
  // `updateProfileDetails`-dir (Admin SDK) — rezervasiya dəyişimi,
  // kuldaunlar və `nameLower` törəməsi orada, bir tranzaksiyada.
  // Tam əhatə: `firestore-profile-identity.test.ts`.
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
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "users", ATTACKER), { username: "alice" }));
  });

  test("HEÇ KİMİN rezerv etmədiyi handle-ı yazmaq da RƏDD EDİLİR", async () => {
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "users", ATTACKER), { username: "bosdur_bu_handle" }));
  });

  test("`isReservedUsername` blocklist-i bu yolla da keçilə bilmir", async () => {
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "users", ATTACKER), { username: "admin" }));
  });

  test("ÖZ rezervasiyasını tutmaq da artıq KİFAYƏT ETMİR", async () => {
    // Köhnə axının tam forması — rezervasiya artıq bu uid-dədir. Əvvəllər
    // keçirdi; indi keçmir, çünki kuldaun klientin yaza bildiyi yerdə
    // saxlana bilməz. `updateProfileDetails` eyni yazını, eyni
    // yoxlamalarla, üstəgəl 30 günlük limitlə edir.
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "users", ATTACKER), { username: `user_${ATTACKER}_yeni` }));
  });

  test("username-ə TOXUNMAYAN redaktə hələ də keçir", async () => {
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", ATTACKER), { bio: "yeni bio" }));
  });
});

describe("A4 — users.nameLower artıq klientdən gəlmir", () => {
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
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), { nameLower: "tamam basqa adam" }));
  });

  test("adı dəyişmədən nameLower-i dəyişmək rədd edilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), { nameLower: "ad soyad basqa" }));
  });

  test("UYĞUN cütlük də rədd edilir — köhnə batch artıq keçmir", async () => {
    // Klientin köhnə `WriteBatch`-i tam olaraq bu idi. İndi rədd olunur;
    // ekran `updateProfileDetails`-ə keçdi (`ProfileController.save`).
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), {
      firstName: "Yeni", lastName: "Ad", nameLower: "yeni ad",
    }));
  });

  test("Azərbaycan hərfli ad da rədd edilir — indi ARDICIL olaraq", async () => {
    // Əsas məqam: əvvəl bu ad rədd, ASCII ad qəbul edilirdi — yəni
    // qaydanın davranışı istifadəçinin adının hərflərindən asılı idi.
    // İndi hər ikisi eyni yolla, serverdən keçir.
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), {
      firstName: "Əli", lastName: "Məmmədov", nameLower: "əli məmmədov",
    }));
  });
});
