// BACKLOG #22 — `subscription_overdue` admin paneldə "approved" kimi
// görünürdü.
//
// Kök səbəb `parseStatus`-un tanımadığı hər dəyəri `"approved"`-a
// çevirməsi idi. `renewVenueSubscriptions` isə ödəniş gecikəndə məkanı
// məhz həmin statusa qoyur — yəni borclu, tətbiqdə görünməyən məkan
// admin paneldə **aktiv** görünürdü. Defoltun xoşagələn tərəfə
// yığılması: eyni sinif səhv admin roster-ində də vardı.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import { isVenueStatus, type VenueModerationStatus, type VenueStatus } from "../../admin-panel/src/lib/venue-status";

describe("VenueStatus — göstəriş birləşməsi", () => {
  test("subscription_owerdue deyil, subscription_overdue tanınır", () => {
    assert.equal(isVenueStatus("subscription_overdue"), true);
  });

  test("hər real status tanınır", () => {
    for (const s of [
      "approved", "pending", "needs_revision", "rejected",
      "inactive", "awaiting_payment", "subscription_overdue",
    ]) {
      assert.equal(isVenueStatus(s), true, s);
    }
  });

  test("uydurma dəyər tanınmır", () => {
    for (const s of ["APPROVED", "overdue", "", null, undefined, 3, {}]) {
      assert.equal(isVenueStatus(s), false, JSON.stringify(s));
    }
  });
});

describe("VenueModerationStatus — yazıla bilən altçoxluq", () => {
  // Tip səviyyəsində yoxlama: aşağıdakı təyinatlar kompilyasiya
  // olunursa, altçoxluq düzgündür. `subscription_overdue` və
  // `awaiting_payment` bura DAXİL OLSAYDI, sonuncu blok kompilyasiya
  // xətası verərdi — yəni bu test `tsc`-nin özü ilə işləyir.
  test("moderasiya statusları göstəriş birləşməsinin alt çoxluğudur", () => {
    const writable: VenueModerationStatus[] = [
      "approved", "pending", "needs_revision", "rejected", "inactive",
    ];
    const displayable: VenueStatus[] = [...writable, "awaiting_payment", "subscription_overdue"];
    assert.equal(writable.length, 5);
    assert.equal(displayable.length, 7);
    for (const s of writable) assert.equal(isVenueStatus(s), true, s);
  });

  test("billing statusları yazıla bilən siyahıda deyil", () => {
    // `setVenueStatus` bunları qəbul etməməlidir: admin əl ilə məkanı
    // borclu edə və ya borcunu "silə" bilməməlidir — hər iki halda
    // uyğun ödəniş qeydi olmadan.
    const writable: readonly string[] = ["approved", "pending", "needs_revision", "rejected", "inactive"];
    assert.equal(writable.includes("subscription_overdue"), false);
    assert.equal(writable.includes("awaiting_payment"), false);
  });
});
