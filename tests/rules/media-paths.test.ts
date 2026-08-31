/**
 * Derived Storage paths (`functions/src/media-paths.ts`) and their
 * admin-panel twin.
 *
 * These paths decide which object a delete addresses. The alternative —
 * parsing the stored `mediaUrl`/`coverImageUrl` — is what let a
 * client-written string reach `bucket.file().delete()` on the Admin SDK
 * (P0 / C-1, and its 2026-08-31 recurrence in the admin panel). So the
 * property under test is that NOTHING a client writes can influence the
 * result: every input here is an owner uid and a document id.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  eventCoverPath,
  offerPhotoPath,
  pinboxPhotoPath,
  storyMediaPath,
  venuePhotoPath,
} from "../../functions/src/media-paths";
import { eventCoverPath as adminEventCoverPath } from "../../admin-panel/src/lib/media-paths";

describe("deterministik yollar client-in yazdığı heç nədən asılı deyil", () => {
  test("venue_photos", () => {
    assert.equal(venuePhotoPath("owner1", "venue1"), "venue_photos/owner1/venue1.jpg");
  });
  test("offer_photos", () => {
    assert.equal(offerPhotoPath("owner1", "offer1"), "offer_photos/owner1/offer1.jpg");
  });
  test("pinbox_photos", () => {
    assert.equal(pinboxPhotoPath("owner1", "box1"), "pinbox_photos/owner1/box1.jpg");
  });
  test("event_covers", () => {
    assert.equal(eventCoverPath("owner1", "event1"), "event_covers/owner1/event1.jpg");
  });
  test("story şəkli və videosu uzantı ilə ayrılır", () => {
    assert.equal(storyMediaPath("u1", "s1", "image"), "stories/u1/s1.jpg");
    assert.equal(storyMediaPath("u1", "s1", "video"), "stories/u1/s1.mp4");
  });
});

describe("etibarsız giriş — null, uydurma yol YOX", () => {
  test("traversal cəhdi rədd edilir", () => {
    // Firestore id-ləri `/` daşıya bilmir, amma bu, struktur
    // təsdiqidir: modulun çıxışı çağırışçı tərəfindən yenidən
    // yoxlanmadan istifadə edilir.
    assert.equal(venuePhotoPath("../../evil", "v1"), null);
    assert.equal(venuePhotoPath("o1", "../secret"), null);
    assert.equal(eventCoverPath("o1", "a/b"), null);
  });

  test("boş və ədəd dəyərlər rədd edilir", () => {
    for (const bad of [undefined, null, "", 42, {}]) {
      assert.equal(venuePhotoPath(bad, "v1"), null);
      assert.equal(venuePhotoPath("o1", bad), null);
    }
  });

  test("tanınmayan mediaType üçün uzantı UYDURULMUR", () => {
    // Yanlış uzantı seçmək heç nə silməyib "uğurlu" hesab etmək
    // deməkdir — ən pis hal.
    assert.equal(storyMediaPath("u1", "s1", "gif"), null);
    assert.equal(storyMediaPath("u1", "s1", undefined), null);
  });
});

describe("admin panel əkizi ilə paritet", () => {
  test("eventCoverPath hər iki tərəfdə eyni nəticə verir", () => {
    for (const [o, e] of [["owner1", "event1"], ["a", "b"], ["../x", "e"], ["", "e"]] as const) {
      assert.equal(adminEventCoverPath(o, e), eventCoverPath(o, e), `${o}/${e}`);
    }
  });
});
