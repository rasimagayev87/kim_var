// A3-H1 — sahib öz faylını silə bilirmi.
//
// Audit 3-də bu, müvəqqəti bir probe idi; düzəliş edildikdən sonra
// daimi regressiya testinə çevrildi. Sınadığı şey incədir: DELETE
// sorğusunda `request.resource` MÖVCUD DEYİL, ona görə `delete`
// verən bir qaydada ölçü/tip şərti olması silməni qiymətləndirilə
// bilməz edir və rədd etdirir. Qayda `allow write` yazdığı müddətcə
// bu, kompilyasiya xətası vermir, testsiz də görünmür — istifadəçi
// sadəcə "sildim" görür və fayl qalır.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteObject, ref, uploadBytes } from "firebase/storage";

import { createTestEnv } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0, 1, 2, 3]);

/** Storage emulator-un rules mühərriki ilk yazıda gecikə bilər —
 * `storage-prompt3.test.ts`-dəki eyni isinmə. */
before(async () => {
  testEnv = await createTestEnv();
  for (let i = 0; i < 5; i++) {
    try {
      await uploadBytes(
        ref(testEnv.authenticatedContext("warmup").storage(), "profile_photos/warmup/w.jpg"),
        jpeg,
        { contentType: "image/jpeg" },
      );
      break;
    } catch {
      await new Promise((r) => setTimeout(r, 300));
    }
  }
});

after(async () => {
  await testEnv.cleanup();
});

const OWNER_PATHS: Array<[string, string]> = [
  ["profile_photos", "profile_photos/alice/a.jpg"],
  ["stories", "stories/alice/s.jpg"],
  ["posts", "posts/alice/p.jpg"],
  ["venue_photos", "venue_photos/alice/v1.jpg"],
  ["offer_photos", "offer_photos/alice/o1.jpg"],
  ["pinbox_photos", "pinbox_photos/alice/pb1.jpg"],
  ["event_covers", "event_covers/alice/e1.jpg"],
];

describe("A3-H1 — sahib-əsaslı yollarda silmə", () => {
  for (const [label, path] of OWNER_PATHS) {
    test(`${label}: sahib yükləyir və SİLİR`, async () => {
      const alice = testEnv.authenticatedContext("alice").storage();
      await assertSucceeds(uploadBytes(ref(alice, path), jpeg, { contentType: "image/jpeg" }));
      await assertSucceeds(deleteObject(ref(alice, path)));
    });

    test(`${label}: özgə silə BİLMİR`, async () => {
      const alice = testEnv.authenticatedContext("alice").storage();
      const mallory = testEnv.authenticatedContext("mallory").storage();
      await assertSucceeds(uploadBytes(ref(alice, path), jpeg, { contentType: "image/jpeg" }));
      await assertFails(deleteObject(ref(mallory, path)));
    });
  }

  test("chat_photos: göndərən silir, alan silə bilmir (RT-8, dəyişməyib)", async () => {
    const alice = testEnv.authenticatedContext("alice").storage();
    const bob = testEnv.authenticatedContext("bob").storage();
    const p = "chat_photos/alice_bob/alice/m1.jpg";
    await assertSucceeds(uploadBytes(ref(alice, p), jpeg, { contentType: "image/jpeg" }));
    await assertFails(deleteObject(ref(bob, p)));
    await assertSucceeds(deleteObject(ref(alice, p)));
  });
});

describe("identity_verifications — silmənin bloklanması QƏSDƏNDİR", () => {
  // Yuxarıdakı düzəlişin eyni forması burada TƏTBİQ EDİLMƏYİB. Bu test
  // həmin qərarı icra edilə bilən şəkildə qeydə alır: KYC sübutu
  // moderator baxarkən yox olmamalıdır və rədd edildikdən sonra
  // "təmiz" sənədlə əvəzlənməməlidir. Təmizləmə
  // `cleanupExpiredIdentityVerificationImages`-in işidir.
  test("sahib öz KYC şəklini silə bilmir", async () => {
    const alice = testEnv.authenticatedContext("alice").storage();
    const p = "identity_verifications/alice/req1/front.jpg";
    await assertSucceeds(uploadBytes(ref(alice, p), jpeg, { contentType: "image/jpeg" }));
    await assertFails(deleteObject(ref(alice, p)));
  });
});
