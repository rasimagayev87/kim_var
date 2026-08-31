// Paritet — abunə qiymət cədvəli iki kod bazasında eynidir.
//
// Bu cədvəl pulu təyin edir. Fərqlənsə, admin panel bir məbləğ
// göstərər, `renewVenueSubscriptions` başqa məbləğ tutar, və bunu
// yalnız məkan sahibi şikayət edəndə bilərik.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  categoriesAtFee,
  OFFER_ONLY_VENUE_CATEGORIES,
  SUBSCRIPTION_FEE_TIERS,
  venueSubscriptionFeeByCategory,
} from "../../functions/src/venue-fees";
import {
  categoriesAtFee as adminCategoriesAtFee,
  OFFER_ONLY_VENUE_CATEGORIES as adminOfferOnly,
  SUBSCRIPTION_FEE_TIERS as adminTiers,
  venueSubscriptionFeeByCategory as adminFees,
} from "../../admin-panel/src/lib/venue-fees";

describe("venue-fees — iki kod bazası arasında paritet", () => {
  test("kateqoriya siyahısı eynidir", () => {
    assert.deepEqual(
      Object.keys(venueSubscriptionFeeByCategory).sort(),
      Object.keys(adminFees).sort(),
    );
  });

  test("hər kateqoriyanın qiyməti eynidir", () => {
    for (const [category, fee] of Object.entries(venueSubscriptionFeeByCategory)) {
      assert.equal(adminFees[category], fee, `${category}: ${fee} vs ${adminFees[category]}`);
    }
  });

  test("yalnız-təklif kateqoriyaları eynidir", () => {
    assert.deepEqual([...OFFER_ONLY_VENUE_CATEGORIES].sort(), [...adminOfferOnly].sort());
  });

  test("tarif qrupları eynidir", () => {
    assert.deepEqual([...SUBSCRIPTION_FEE_TIERS], [...adminTiers]);
    for (const tier of SUBSCRIPTION_FEE_TIERS) {
      assert.deepEqual(categoriesAtFee(tier).sort(), adminCategoriesAtFee(tier).sort(), `tarif ${tier}`);
    }
  });
});

describe("venue-fees — cədvəlin öz bütövlüyü", () => {
  test("hər kateqoriyanın müsbət tam qiyməti var", () => {
    for (const [category, fee] of Object.entries(venueSubscriptionFeeByCategory)) {
      assert.ok(Number.isInteger(fee) && fee > 0, `${category}: ${fee}`);
    }
  });

  test("hər yalnız-təklif kateqoriyasının da qiyməti var", () => {
    // Onlar da abunə ödəyir — sadəcə tədbir/PinBox/növbə yarada bilmir.
    for (const category of OFFER_ONLY_VENUE_CATEGORIES) {
      assert.ok(venueSubscriptionFeeByCategory[category] !== undefined, category);
    }
  });

  test("hər tarif qrupu Firestore `in` limitinin (30) altındadır", () => {
    // Kateqoriya bölgüsü tarif başına bir `in` sorğusu ilə hesablanır;
    // bir qrup 30-u keçsə, həmin sorğu işləməz.
    for (const tier of SUBSCRIPTION_FEE_TIERS) {
      const n = categoriesAtFee(tier).length;
      assert.ok(n <= 30, `${tier} AZN qrupunda ${n} kateqoriya var — 30 limitini keçir`);
    }
  });

  test("qruplar bütün kateqoriyaları örtür, üst-üstə düşmədən", () => {
    const all = SUBSCRIPTION_FEE_TIERS.flatMap((t) => categoriesAtFee(t));
    assert.equal(all.length, Object.keys(venueSubscriptionFeeByCategory).length);
    assert.equal(new Set(all).size, all.length, "kateqoriya iki qrupda görünür");
  });
});
