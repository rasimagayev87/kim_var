// P0 / H-5 — media URL-ləri yalnız bizim öz Storage bucket-imizə işarə
// edə bilər.
//
// İki ayrı zərər: (1) xarici URL hər baxan istifadəçinin cihazını
// müəllifin serverinə sorğu göndərməyə məcbur edir (IP toplama —
// yaxınlıq tətbiqi üçün deanonimləşdirmə), (2) moderator URL-dəki
// BAYTLARI təsdiqləyir, müəllif isə sonradan onları dəyişir və heç bir
// Firestore yazısı baş vermədiyi üçün elan yenidən moderasiyaya düşmür.
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

async function seed(fn: (fs: ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"]) => Promise<void>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

const OK = "https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/profile_photos%2Fu%2Fp.jpg?alt=media&token=t";

// Hər biri ayrı bir keçid cəhdi: açıq xarici host, oxşar-ad hücumu,
// alt-domen hücumu, sxem dəyişikliyi, data URI.
const HOSTILE = [
  "https://tracker.example/px.jpg",
  "https://firebasestorage.googleapis.com.evil.test/v0/b/kim-var-73ce9.firebasestorage.app/o/x.jpg",
  "https://evil.firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/x.jpg",
  "http://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/x.jpg",
  "https://firebasestorage.googleapis.com/v0/b/BASQA-BUCKET.firebasestorage.app/o/x.jpg",
  "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=",
];

const U = "p0h5-user";
const OWNER = "p0h5-owner";
const VENUE = "p0h5-venue";

describe("P0 / H-5 — users.photoUrl", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", U), userFixture(U, { photoUrl: OK }));
    });
  });

  test("öz bucket-imizin URL-i qəbul edilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", U), { photoUrl: OK }));
  });

  test("photoUrl-suz yeniləmə işləyir (sahə opsionaldır)", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", U), { bio: "salam" }));
  });

  for (const url of HOSTILE) {
    test(`rədd edilir: ${url.slice(0, 55)}`, async () => {
      const db = testEnv.authenticatedContext(U).firestore();
      await assertFails(updateDoc(doc(db, "users", U), { photoUrl: url }));
    });
  }
});

describe("P0 / H-5 — posts.mediaUrl və stories.mediaUrl", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", U), userFixture(U));
    });
  });

  test("öz bucket-imizin URL-i ilə post/story yaradıla bilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(setDoc(doc(db, "posts", "p0h5-ok-post"), { userId: U, mediaUrl: OK, caption: "a" }));
    await assertSucceeds(setDoc(doc(db, "stories", "p0h5-ok-story"), { creatorId: U, mediaUrl: OK }));
  });

  test("xarici URL ilə post yaradıla BİLMİR", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(db, "posts", "p0h5-bad-post"), { userId: U, mediaUrl: "https://tracker.example/x.mp4" }),
    );
  });

  test("xarici thumbnailUrl ilə post yaradıla BİLMİR", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(db, "posts", "p0h5-bad-thumb"), { userId: U, mediaUrl: OK, thumbnailUrl: "https://tracker.example/t.jpg" }),
    );
  });

  test("xarici URL ilə story yaradıla BİLMİR", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(db, "stories", "p0h5-bad-story"), { creatorId: U, mediaUrl: "https://tracker.example/s.jpg" }),
    );
  });
});

describe("P0 / H-5 — pinboxes.imageUrl və venueEvents.coverImageUrl", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", OWNER), userFixture(OWNER));
      await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER));
    });
  });

  const pinbox = (imageUrl: string) => ({
    ownerId: OWNER,
    venueId: VENUE,
    status: "pending",
    stockTotal: 5,
    stockRemaining: 5,
    title: "Qutu",
    imageUrl,
  });

  test("PinBox öz bucket-imizin şəkli ilə yaradıla bilir", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(setDoc(doc(db, "pinboxes", "p0h5-ok-pb"), pinbox(OK)));
  });

  test("PinBox xarici şəkillə yaradıla BİLMİR", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(setDoc(doc(db, "pinboxes", "p0h5-bad-pb"), pinbox("https://tracker.example/b.jpg")));
  });

  test("tədbir öz bucket-imizin cover-i ilə yaradıla bilir", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      setDoc(doc(db, "venueEvents", "p0h5-ok-ev"), {
        venueId: VENUE,
        // Events are created as `pending` since the trust-based
        // moderation change; this test is about the cover URL only.
        status: "pending",
        title: "Tədbir",
        coverImageUrl: OK,
      }),
    );
  });

  test("tədbir xarici cover ilə yaradıla BİLMİR", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      setDoc(doc(db, "venueEvents", "p0h5-bad-ev"), {
        venueId: VENUE,
        status: "upcoming",
        title: "Tədbir",
        coverImageUrl: "https://tracker.example/c.jpg",
      }),
    );
  });

  test("mövcud tədbirin cover-i xarici URL-ə DƏYİŞDİRİLƏ bilmir (təsdiqdən sonra swap)", async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "venueEvents", "p0h5-live-ev"), {
        venueId: VENUE,
        status: "live",
        title: "Tədbir",
        coverImageUrl: OK,
      });
    });
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      updateDoc(doc(db, "venueEvents", "p0h5-live-ev"), { coverImageUrl: "https://tracker.example/c.jpg" }),
    );
  });
});
