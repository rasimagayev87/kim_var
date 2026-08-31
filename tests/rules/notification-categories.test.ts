/**
 * Which notifications a user can silence, and which they cannot.
 *
 * The audit that produced these tests found seventeen transactional
 * messages sitting behind content toggles: "Məkan təklifləri" also
 * gated "ödənişiniz uğursuz oldu", and "Məkan yenilikləri" also gated
 * "sıra sizindir" — sent to someone standing outside the venue.
 *
 * So the assertions here are not about the map being tidy. They are:
 *
 *   1. every transactional type is UNGATED — nobody can "simplify"
 *      the gate back into applying to everything;
 *   2. every content type IS gated — the toggles are not decoration;
 *   3. the map matches what `index.ts` actually passes, verified by
 *      parsing it, so the two cannot drift;
 *   4. no preference key exists that nothing reads.
 *
 * (3) is the load-bearing one. A table that merely claims to describe
 * 36 call sites is documentation; a table checked against them is a
 * boundary.
 */
import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { describe, test } from "node:test";

import {
  ALL_NOTIFICATION_PREFERENCE_KEYS,
  GATED_NOTIFICATION_CATEGORIES,
  isGatedCategory,
  NOTIFICATION_CATEGORY_BY_TYPE,
  UNGATED_NOTIFICATION_CATEGORIES,
} from "../../functions/src/notification-categories";

const INDEX = readFileSync("../../functions/src/index.ts", "utf8");
const PREFS_DART = readFileSync(
  "../../lib/features/settings/notifications/domain/entities/notification_preferences.dart",
  "utf8",
);
const SCREEN_DART = readFileSync(
  "../../lib/features/settings/notifications/presentation/screens/notifications_screen.dart",
  "utf8",
);

/** Every `notifyUser({...})` call in index.ts, as (category, types). */
function notifyUserCalls(): { line: number; category: string; types: string[] }[] {
  const out: { line: number; category: string; types: string[] }[] = [];
  const re = /notifyUser\(\s*\{/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(INDEX)) !== null) {
    let i = INDEX.indexOf("{", m.index);
    let depth = 0;
    let j = i;
    for (; j < INDEX.length; j++) {
      if (INDEX[j] === "{") depth++;
      else if (INDEX[j] === "}" && --depth === 0) break;
    }
    const body = INDEX.slice(i, j);
    const cat = /category:\s*"([^"]+)"/.exec(body);
    if (!cat) continue;
    const typeLine = /type:\s*([^\n]+)/.exec(body);
    // `type` is a literal, a ternary of two literals, or absent
    // (spread from `moderationStatusNotification`).
    const types = typeLine ? [...typeLine[1].matchAll(/"([A-Za-z]+)"/g)].map((t) => t[1]) : [];
    out.push({ line: INDEX.slice(0, m.index).split("\n").length, category: cat[1], types });
  }
  return out;
}

/** The nine `${kind}${Outcome}` types `moderationStatusNotification` builds. */
const MODERATION_TYPES = ["venue", "offer", "pinbox"].flatMap((k) => [
  `${k}Approved`,
  `${k}NeedsRevision`,
  `${k}Rejected`,
]);

describe("notifyUser qapısı — nə söndürülə bilər", () => {
  test("qapısız kateqoriyalar DƏQİQ security və account-dur", () => {
    // Bu siyahının dəyişməsi məhsul qərarıdır, refaktor deyil.
    assert.deepEqual([...UNGATED_NOTIFICATION_CATEGORIES].sort(), ["account", "security"]);
  });

  test("isGatedCategory qapısızları buraxır, qalanını qapılı sayır", () => {
    for (const c of UNGATED_NOTIFICATION_CATEGORIES) assert.equal(isGatedCategory(c), false, c);
    for (const c of GATED_NOTIFICATION_CATEGORIES) assert.equal(isGatedCategory(c), true, c);
  });

  test("index.ts qapını YALNIZ isGatedCategory ilə tətbiq edir", () => {
    // Şərtsiz `prefs[params.category] === false` geri qayıdarsa,
    // ödəniş və növbə bildirişləri yenidən söndürülə bilən olar.
    assert.match(
      INDEX,
      /if \(isGatedCategory\(params\.category\) && prefs\[params\.category\] === false\) return;/,
      "notifyUser-in qapısı isGatedCategory-siz yazılıb",
    );
  });
});

describe("HƏR TRANZAKSİYA TİPİ QAPISIZDIR", () => {
  // Sizin tələbiniz: gələcəkdə kimsə "hamısını qapılı edək" deyə
  // sadələşdirməsin. Hər ad ayrıca yazılıb ki, biri düşəndə test
  // adı ilə birlikdə xəbər versin.
  const MUST_BE_UNGATED = [
    // pul
    "offerPaymentConfirmed", "offerBoosted", "paymentFailed", "pinboxOrderConfirmed",
    "venuePaymentConfirmed", "venueSubscriptionRenewed", "venueSubscriptionDue",
    "venuePremiumActivated", "venuePremiumExpiringSoon",
    // kimlik və hüquq
    "identityVerificationApproved", "identityVerificationRejected", "vipGranted",
    // növbə — vaxt-həssas fiziki hadisə
    "venueWaitlistJoined", "waitlistCalled", "waitlistDisabled",
    // öz elanının moderasiya nəticəsi (ödənişin nəticəsidir)
    ...MODERATION_TYPES,
    // sahibə gedən yaratma təsdiqləri
    "pinboxAdded", "venueAdded", "venueVerified",
    // təhlükəsizlik
    "security",
  ];

  for (const type of MUST_BE_UNGATED) {
    test(`${type} söndürülə bilməz`, () => {
      const category = NOTIFICATION_CATEGORY_BY_TYPE[type];
      assert.ok(category, `${type} xəritədə yoxdur`);
      assert.equal(
        isGatedCategory(category),
        false,
        `${type} "${category}" altındadır və söndürülə bilir`,
      );
    });
  }
});

describe("HƏR MƏZMUN TİPİ QAPILIDIR", () => {
  // Əks istiqamət: toggle-lar bəzək olmamalıdır.
  const MUST_BE_GATED: Record<string, string> = {
    dailyOffersDigest: "venueOffers",
    dailyPinboxDigest: "venueOffers",
    dailyEventsDigest: "venueOffers",
    birthdayOffer: "venueOffers",
    venuePeakHour: "venueUpdates",
    birthdayMatch: "venueUpdates",
    reviewPrompt: "venueUpdates",
    followRequest: "followers",
    newFollower: "followers",
    followAccepted: "followers",
    likePost: "likes",
    commentPost: "comments",
    replyComment: "comments",
    mention: "comments",
  };

  for (const [type, expected] of Object.entries(MUST_BE_GATED)) {
    test(`${type} → ${expected}, söndürülə bilir`, () => {
      assert.equal(NOTIFICATION_CATEGORY_BY_TYPE[type], expected);
      assert.equal(isGatedCategory(expected), true);
    });
  }
});

describe("PARİTET — xəritə index.ts-in faktiki çağırışları ilə üst-üstə düşür", () => {
  const calls = notifyUserCalls();

  test("çağırışlar tapıldı (parser sınmayıb)", () => {
    assert.ok(calls.length >= 30, `yalnız ${calls.length} çağırış tapıldı`);
  });

  test("hər çağırışın kateqoriyası tanınandır", () => {
    const known = new Set([...GATED_NOTIFICATION_CATEGORIES, ...UNGATED_NOTIFICATION_CATEGORIES]);
    for (const c of calls) {
      assert.ok(known.has(c.category), `index.ts:${c.line} tanınmayan kateqoriya "${c.category}"`);
    }
  });

  test("hər literal tipin faktiki kateqoriyası xəritə ilə eynidir", () => {
    for (const c of calls) {
      for (const t of c.types) {
        assert.ok(NOTIFICATION_CATEGORY_BY_TYPE[t], `index.ts:${c.line} "${t}" xəritədə yoxdur`);
        assert.equal(
          NOTIFICATION_CATEGORY_BY_TYPE[t],
          c.category,
          `index.ts:${c.line} "${t}" faktiki "${c.category}", xəritədə "${NOTIFICATION_CATEGORY_BY_TYPE[t]}"`,
        );
      }
    }
  });

  test("literal tipi olmayan çağırışların hər biri gözlənilən kateqoriyadadır", () => {
    // İki cür çağırış literal `type:` daşımır: moderasiya nəticələri
    // (`...notification` spread) və gündəlik digest (tipi
    // `DIGEST_NOTIFICATION_TYPE[type]` lüğətindən gəlir). Hər ikisi
    // burada AÇIQ sadalanır ki, yeni bir dinamik çağırış səssizcə
    // əlavə edilə bilməsin.
    const dynamic = calls.filter((c) => c.types.length === 0);
    const byCategory = dynamic.reduce<Record<string, number>>((acc, c) => {
      acc[c.category] = (acc[c.category] ?? 0) + 1;
      return acc;
    }, {});
    assert.deepEqual(
      byCategory,
      { account: 3, venueOffers: 1 },
      `gözlənilən 3 moderasiya (account) + 1 digest (venueOffers), tapıldı ${JSON.stringify(byCategory)}`,
    );
  });

  test("məzmun kateqoriyalarında ARTIQ heç bir tranzaksiya tipi yoxdur", () => {
    const contentCalls = calls.filter((c) => c.category === "venueOffers" || c.category === "venueUpdates");
    const seen = contentCalls.flatMap((c) => c.types);
    for (const banned of ["paymentFailed", "waitlistCalled", "vipGranted", "venueSubscriptionDue"]) {
      assert.ok(!seen.includes(banned), `${banned} yenidən məzmun kateqoriyasına düşüb`);
    }
    // 4 idi (venueOffer/pinboxNearby/venueEvent/birthdayOffer) + 3
    // venueUpdates = 7. Üç fan-out silindi, yerinə bir digest çağırışı
    // gəldi: 1 birthdayOffer + 1 digest + 3 venueUpdates = 5.
    assert.equal(contentCalls.length, 5, `məzmun çağırışı sayı gözlənilən 5, alındı ${contentCalls.length}`);
  });
});

describe("ÖLÜ AÇAR QALMAYIB", () => {
  test("client entity-si yalnız serverin oxuduğu açarları saxlayır", () => {
    const dartFields = [...PREFS_DART.matchAll(/final bool (\w+);/g)].map((m) => m[1]);
    assert.deepEqual(
      dartFields.sort(),
      [...ALL_NOTIFICATION_PREFERENCE_KEYS]
        .filter((k) => !UNGATED_NOTIFICATION_CATEGORIES.includes(k))
        .sort(),
      "Dart entity-si ilə server açarları fərqlənir",
    );
  });

  test("newUsers və emailEnabled tamamilə silinib", () => {
    for (const dead of ["newUsers", "emailEnabled"]) {
      assert.ok(!PREFS_DART.includes(`bool ${dead}`), `${dead} entity-də qalıb`);
      assert.ok(!INDEX.includes(`"${dead}"`), `${dead} index.ts-də qalıb`);
    }
  });

  test("security artıq saxlanan açar deyil — qapısız olduğu üçün açar mənasızdır", () => {
    assert.ok(!PREFS_DART.includes("bool security"), "security entity-də qalıb, amma heç nəyi idarə etmir");
  });

  test("hər qapılı kateqoriyanın UI-da açarı var — ölü toggle-ın əksi", () => {
    for (const key of GATED_NOTIFICATION_CATEGORIES) {
      if (key === "messages" || key === "followers" || key === "likes" || key === "comments") {
        // sadə adlar — ekranda birbaşa sətir kimi
        assert.ok(SCREEN_DART.includes(`'${key}'`), `${key} üçün UI açarı yoxdur`);
      } else {
        assert.ok(SCREEN_DART.includes(`'${key}'`), `${key} üçün UI açarı yoxdur`);
      }
    }
  });
});

describe("marketing OPT-IN-dir — hər iki tərəfdə", () => {
  test("Dart defolt-u false", () => {
    assert.match(PREFS_DART, /this\.marketing = false/);
  });

  test("digər kateqoriyaların Dart defolt-u true", () => {
    for (const k of GATED_NOTIFICATION_CATEGORIES) {
      if (k === "marketing") continue;
      assert.match(PREFS_DART, new RegExp(`this\\.${k} = true`), `${k} defolt-u true deyil`);
    }
  });

  test("admin broadcast marketing üçün === true tələb edir, digərləri üçün !== false", () => {
    const broadcast = readFileSync("../../admin-panel/src/lib/actions/broadcast.ts", "utf8");
    assert.match(broadcast, /const optInOnly = prefKey === "marketing";/);
    assert.match(broadcast, /optInOnly \? value === true : value !== false/);
  });
});
