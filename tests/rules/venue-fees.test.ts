// Paritet — abunə qiymət cədvəli iki kod bazasında eynidir.
//
// Bu cədvəl pulu təyin edir. Fərqlənsə, admin panel bir məbləğ
// göstərər, `renewVenueSubscriptions` başqa məbləğ tutar, və bunu
// yalnız məkan sahibi şikayət edəndə bilərik.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import { readFileSync } from "node:fs";

import {
  categoriesAtFee,
  FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER,
  freeCampaignQuotaForCategory,
  OFFER_ONLY_VENUE_CATEGORIES,
  SUBSCRIPTION_FEE_TIERS,
  venueSubscriptionFeeByCategory,
} from "../../functions/src/venue-fees";
import {
  categoriesAtFee as adminCategoriesAtFee,
  FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER as adminQuotas,
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

describe("pulsuz kampaniya kvotası", () => {
  test("cədvəlin açarları DƏQİQ abunə tarifləridir", () => {
    // Bu, testin ən vacib iddiasıdır. Beşinci tarif qiymət cədvəlinə
    // əlavə edilib buraya əlavə edilməsə, `freeCampaignQuotaForCategory`
    // `undefined` qaytarar — bu isə "pulsuz kampaniya yoxdur" kimi
    // oxunur və bütöv bir tarif səssizcə hər kampaniya üçün ödəməyə
    // başlayar. Səhv özünü göstərməz, çünki heç nə sınmaz.
    assert.deepEqual(
      Object.keys(FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER).map(Number).sort((a, b) => b - a),
      [...SUBSCRIPTION_FEE_TIERS],
    );
  });

  test("məhsul qərarı: 15→3, 20→5, 25→8, 30→10", () => {
    assert.deepEqual(FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER, { 15: 3, 20: 5, 25: 8, 30: 10 });
  });

  test("HƏR kateqoriya kvota alır", () => {
    for (const category of Object.keys(venueSubscriptionFeeByCategory)) {
      const quota = freeCampaignQuotaForCategory(category);
      assert.ok(typeof quota === "number" && quota > 0, `${category} kvotasız qaldı`);
    }
  });

  test("naməlum kateqoriya undefined qaytarır, 0 yox", () => {
    // 0 "kvotası bitib" deməkdir və ödənişli axına düşür; undefined
    // isə `submitOffer`-də ayrıca yoxlanılır. İkisi qarışdırılmamalıdır.
    assert.equal(freeCampaignQuotaForCategory("uydurmaKateqoriya"), undefined);
  });

  test("admin panel nüsxəsi eynidir", () => {
    assert.deepEqual(FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER, adminQuotas);
  });

  test("Dart nüsxəsi eynidir — yerləşdirmə haqqından törəyir", () => {
    // Dart tərəf kateqoriya cədvəlini təkrarlamır, `2/4/5/7 AZN`
    // yerləşdirmə haqqından map edir. Bu test həmin map-in TS
    // cədvəli ilə uyğunluğunu qoruyur.
    const dart = readFileSync(new URL("../../lib/features/offers/domain/entities/offer.dart", import.meta.url), "utf8");
    const body = /int freeCampaignQuotaFor\(VenueCategory category\) \{([\s\S]*?)\n\}/.exec(dart);
    assert.ok(body, "freeCampaignQuotaFor Dart-da tapılmadı");
    const dartMap = Object.fromEntries(
      [...body[1].matchAll(/(\d+)\s*=>\s*(\d+)/g)].map((m) => [Number(m[1]), Number(m[2])]),
    );
    // AZN haqqı → abunə tarifi
    const tierByFee: Record<number, number> = { 2: 15, 4: 20, 5: 25, 7: 30 };
    for (const [fee, quota] of Object.entries(dartMap)) {
      const tier = tierByFee[Number(fee)];
      assert.ok(tier, `Dart-da tanınmayan haqq: ${fee}`);
      assert.equal(quota, FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER[tier], `${fee} AZN haqqı üçün kvota fərqlidir`);
    }
    assert.equal(Object.keys(dartMap).length, SUBSCRIPTION_FEE_TIERS.length);
  });
});
