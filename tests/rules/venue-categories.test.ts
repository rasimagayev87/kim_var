/**
 * The four category allowlists, held identical across three languages.
 *
 * Each list exists in TypeScript (callables), in `firestore.rules`
 * (direct client writes) and in Dart (what the UI offers). None of the
 * three can import the others, so the only thing preventing drift is
 * this file — which parses all three and compares them.
 *
 * The gap that made these lists necessary: the restriction lived ONLY
 * in the Flutter UI, while the server checked a three-item blacklist.
 * PinBox documents are created by a direct client write, so a hotel or
 * a gym owner who bypassed the UI could create one and the rules said
 * yes. Hiding a control is not authorization.
 */
import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { describe, test } from "node:test";

import {
  BIRTHDAY_ELIGIBLE_CATEGORIES,
  EVENT_ELIGIBLE_CATEGORIES,
  isBirthdayCategory,
  isEventCategory,
  isPinBoxCategory,
  isWaitlistCategory,
  PINBOX_ELIGIBLE_CATEGORIES,
  WAITLIST_ELIGIBLE_CATEGORIES,
} from "../../functions/src/venue-categories";

const RULES = readFileSync("../../firestore.rules", "utf8");
const VENUE_DART = readFileSync("../../lib/features/venues/domain/entities/venue.dart", "utf8");

/** The literal list inside a `firestore.rules` helper like
 * `isPinBoxCategory`, in declaration order. */
function rulesList(fnName: string): string[] {
  const fn = new RegExp(`function ${fnName}\\(venueId\\) \\{[\\s\\S]*?in \\[([^\\]]*)\\]`).exec(RULES);
  assert.ok(fn, `${fnName} firestore.rules-da tapılmadı`);
  return [...fn[1].matchAll(/'([a-zA-Z]+)'/g)].map((m) => m[1]);
}

/** The members of a Dart `const kXxx = <VenueCategory>{ ... }` set. */
function dartSet(constName: string): string[] {
  const block = new RegExp(`const ${constName} = <VenueCategory>\\{([\\s\\S]*?)\\};`).exec(VENUE_DART);
  assert.ok(block, `${constName} venue.dart-da tapılmadı`);
  return [...block[1].matchAll(/VenueCategory\.(\w+)/g)].map((m) => m[1]);
}

/** Every value of the Dart `VenueCategory` enum. */
function allCategories(): Set<string> {
  const block = /enum VenueCategory \{([\s\S]*?)\n\}/.exec(VENUE_DART);
  assert.ok(block, "VenueCategory enum tapılmadı");
  return new Set(
    block[1]
      .split("\n")
      .map((l) => l.replace(/\/\/.*$/, "").trim().replace(/,$/, ""))
      .filter((l) => /^[a-z][A-Za-z]*$/.test(l)),
  );
}

const CASES = [
  { name: "Tədbir", ts: EVENT_ELIGIBLE_CATEGORIES, rules: "isEventCategory", dart: "kEventEligibleVenueCategories", size: 7 },
  { name: "PinBox", ts: PINBOX_ELIGIBLE_CATEGORIES, rules: "isPinBoxCategory", dart: "kPinboxEligibleVenueCategories", size: 6 },
  { name: "Növbə", ts: WAITLIST_ELIGIBLE_CATEGORIES, rules: null, dart: "kWaitlistEligibleVenueCategories", size: 10 },
  { name: "Ad günü", ts: BIRTHDAY_ELIGIBLE_CATEGORIES, rules: null, dart: "kBirthdayEligibleVenueCategories", size: 13 },
] as const;

describe("kateqoriya allowlist-ləri — üç tərəfli paritet", () => {
  for (const c of CASES) {
    test(`${c.name}: TypeScript ↔ Dart eynidir`, () => {
      assert.deepEqual([...c.ts].sort(), dartSet(c.dart).sort());
    });

    test(`${c.name}: gözlənilən ölçü ${c.size}`, () => {
      // Ölçünün dəyişməsi məhsul qərarıdır — səssizcə baş verməsin.
      assert.equal(c.ts.length, c.size);
    });

    test(`${c.name}: hər element real VenueCategory-dir`, () => {
      const all = allCategories();
      for (const cat of c.ts) assert.ok(all.has(cat), `"${cat}" enum-da yoxdur`);
    });

    if (c.rules) {
      test(`${c.name}: firestore.rules siyahısı da eynidir`, () => {
        assert.deepEqual(rulesList(c.rules).sort(), [...c.ts].sort());
      });
    }
  }
});

describe("qara siyahı ağ siyahı ilə ƏVƏZLƏNİB, tamamlanmayıb", () => {
  test("pinboxes create artıq isOfferOnlyCategory yoxlamır", () => {
    const block = /match \/pinboxes\/\{pinboxId\} \{[\s\S]*?allow update:/.exec(RULES);
    assert.ok(block);
    assert.ok(block[0].includes("isPinBoxCategory(request.resource.data.venueId)"), "ağ siyahı yoxdur");
    assert.ok(!block[0].includes("isOfferOnlyCategory"), "qara siyahı hələ oradadır");
  });

  test("venueEvents create artıq isOfferOnlyCategory yoxlamır", () => {
    const block = /match \/venueEvents\/\{eventId\} \{[\s\S]*?allow update:/.exec(RULES);
    assert.ok(block);
    assert.ok(block[0].includes("isEventCategory(request.resource.data.venueId)"), "ağ siyahı yoxdur");
    assert.ok(!block[0].includes("isOfferOnlyCategory"), "qara siyahı hələ oradadır");
  });
});

describe("uyğunsuz kateqoriyalar RƏDD EDİLİR", () => {
  // İstifadəçinin bildirdiyi konkret hal: hotel/kino/fitness sahibi
  // UI-nı keçib PinBox yarada bilirdi.
  const NOT_PINBOX = ["hotel", "cinema", "fitness", "gym", "clinic", "carWash", "wineHouse"];
  for (const cat of NOT_PINBOX) {
    test(`${cat} PinBox yarada bilməz`, () => assert.equal(isPinBoxCategory(cat), false));
  }

  test("hotel və kidsEntertainment artıq ad günü siyahısında DEYİL", () => {
    assert.equal(isBirthdayCategory("hotel"), false);
    assert.equal(isBirthdayCategory("kidsEntertainment"), false);
  });

  test("offer-only üçlüyü heç bir siyahıda yoxdur", () => {
    for (const cat of ["wineHouse", "homeServices", "realEstate"]) {
      assert.equal(isEventCategory(cat), false, cat);
      assert.equal(isPinBoxCategory(cat), false, cat);
      assert.equal(isWaitlistCategory(cat), false, cat);
      assert.equal(isBirthdayCategory(cat), false, cat);
    }
  });

  test("ədəd/null/naməlum dəyərlər rədd edilir", () => {
    for (const bad of [undefined, null, 42, "", "notACategory"]) {
      assert.equal(isPinBoxCategory(bad), false);
      assert.equal(isWaitlistCategory(bad), false);
    }
  });
});

describe("növbə siyahısı reviews qapısı ilə uzlaşır", () => {
  test("firestore.rules-un hasVerifiedVisit siyahısı ilə eynidir", () => {
    // Rəy yalnız `seated` növbə girişindən sonra yazıla bilər, ona görə
    // növbəyə icazəli kateqoriyalar ilə rəyə icazəli kateqoriyalar
    // fərqlənə bilməz — biri digərini mənasız edər.
    const reviews = /match \/reviews\/\{reviewId\} \{[\s\S]*?allow create:/.exec(RULES);
    assert.ok(reviews);
    const listed = [...reviews[0].matchAll(/'([a-zA-Z]+)'/g)].map((m) => m[1]);
    for (const cat of WAITLIST_ELIGIBLE_CATEGORIES) {
      assert.ok(listed.includes(cat), `${cat} reviews qapısında yoxdur`);
    }
  });
});

describe("config/* artıq oxunmur", () => {
  test("firestore.rules kateqoriya siyahısı üçün config sənədi OXUMUR", () => {
    // Şərhdə adının çəkilməsi problem deyil — tarixçəni izah edir.
    // Problem `get(.../config/...)` çağırışı olardı. Şərh sətirlərini
    // çıxarıb yalnız icra edilən qaydalara baxırıq.
    const executable = RULES.split("\n")
      .filter((l) => !l.trim().startsWith("//"))
      .join("\n");
    assert.ok(
      !/documents\/config\/(waitlist|event)Categories/.test(executable),
      "rules hələ config kateqoriya sənədini oxuyur",
    );
  });

  test("Dart tərəfi də config provider-lərinə bağlı deyil", () => {
    // `eventCategoryConfigProvider`/`waitlistCategoryConfigProvider`
    // Firestore-dan oxuyurdu; siyahılar koda köçdüyü üçün onların
    // yerini `kEventEligibleVenueCategories`/
    // `kWaitlistEligibleVenueCategories` tutur.
    assert.ok(VENUE_DART.includes("kEventEligibleVenueCategories"));
    assert.ok(VENUE_DART.includes("kWaitlistEligibleVenueCategories"));
  });
});
