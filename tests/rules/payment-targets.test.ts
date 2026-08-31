// Sahibsiz ödəniş qapısı — production-da baş verən hal.
//
// 2026-08-31: məkan yaradıldı, Epoint checkout açıldı, məkan silindi,
// ödəniş `pending` qaldı. Ödəniş gəlsəydi, `tx.update` olmayan sənədə
// yazmağa çalışıb NOT_FOUND atacaq və BÜTÜN tranzaksiyanı geri
// qaytaracaqdı — yəni pul alınıb, ödəniş `pending` qalıb, Epoint
// təkrar-təkrar eyni xətaya düşəcəkdi.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  isCancellableOnListingDelete,
  isPaymentTargetMissing,
  type PaymentTarget,
} from "../../functions/src/payment-targets";

const present = (applies: boolean): PaymentTarget => ({ applies, exists: true });
const missing = (applies: boolean): PaymentTarget => ({ applies, exists: false });

describe("isPaymentTargetMissing", () => {
  test("uğurlu ödəniş + silinmiş məkan → SAHİBSİZ", () => {
    assert.equal(isPaymentTargetMissing(true, [missing(true), missing(false), missing(false)]), true);
  });

  test("uğurlu ödəniş + mövcud məkan → normal", () => {
    assert.equal(isPaymentTargetMissing(true, [present(true), missing(false), missing(false)]), false);
  });

  test("UĞURSUZ ödəniş heç vaxt sahibsiz sayılmır", () => {
    // Silinmiş məkana uğursuz ödəniş sadəcə uğursuz ödənişdir —
    // kimsəyə heç nə borclu deyilik, geri qaytaracaq bir şey yoxdur.
    assert.equal(isPaymentTargetMissing(false, [missing(true), missing(true), missing(true)]), false);
  });

  test("aid olmayan hədəf nəzərə alınmır", () => {
    // `venue_subscription` təklifin mövcudluğu haqqında heç nə demir.
    assert.equal(isPaymentTargetMissing(true, [present(true), missing(false)]), false);
  });

  test("hər üç hədəf tipi ayrıca tutulur", () => {
    // məkan · təklif · pinbox sifarişi
    assert.equal(isPaymentTargetMissing(true, [missing(true), present(false), present(false)]), true);
    assert.equal(isPaymentTargetMissing(true, [present(false), missing(true), present(false)]), true);
    assert.equal(isPaymentTargetMissing(true, [present(false), present(false), missing(true)]), true);
  });

  test("hədəf yoxdursa (heç biri aid deyil) sahibsiz deyil", () => {
    assert.equal(isPaymentTargetMissing(true, [missing(false), missing(false), missing(false)]), false);
    assert.equal(isPaymentTargetMissing(true, []), false);
  });
});

describe("isCancellableOnListingDelete", () => {
  test("yalnız pending ləğv edilir", () => {
    assert.equal(isCancellableOnListingDelete("pending"), true);
  });

  test("completed TOXUNULMUR — pul hərəkət edib", () => {
    // Bu, ən vacib sətirdir: tamamlanmış ödəniş ödədiyi məkandan sonra
    // da yaşamalıdır, əks halda audit izi deyil, cari vəziyyətin
    // keşidir.
    assert.equal(isCancellableOnListingDelete("completed"), false);
  });

  test("digər terminal statuslar toxunulmur", () => {
    for (const s of ["failed", "cancelled", "orphan_target", "refunded", "refund_pending"]) {
      assert.equal(isCancellableOnListingDelete(s), false, s);
    }
  });

  test("superseded toxunulmur — onun yerinə keçən pending tutulacaq", () => {
    assert.equal(isCancellableOnListingDelete("superseded"), false);
  });

  test("naməlum/boş dəyər ləğv edilmir", () => {
    for (const s of [undefined, null, "", 0, {}, "PENDING"]) {
      assert.equal(isCancellableOnListingDelete(s), false, JSON.stringify(s));
    }
  });
});
