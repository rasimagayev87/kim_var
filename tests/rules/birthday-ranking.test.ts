/**
 * The 13:00 birthday ranking (`functions/src/birthday-ranking.ts`).
 *
 * Four numbers decide which venues a person hears about on their
 * birthday, and nothing in the type system stops one of them from
 * drifting. These tests pin the parts that would fail silently: the
 * weights summing to 1, each dimension actually moving the score in
 * the direction it claims, the clamps holding at the extremes, and the
 * distinct-category rule refusing to pad.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  ACTIVE_CAMPAIGN_CAP,
  BIRTHDAY_FEED_MAX,
  BIRTHDAY_HIGHLIGHT_COUNT,
  BIRTHDAY_WEIGHT_TOTAL,
  BIRTHDAY_WEIGHTS,
  BirthdayVenueCandidate,
  PROXIMITY_DEFAULT_REACH_M,
  RICHNESS_TYPES,
  pickDistinctCategoryVenues,
  rankCandidates,
  scoreVenue,
} from "../../functions/src/birthday-ranking";

/** A candidate that scores exactly 0 — every dimension at its floor.
 * Each test raises ONE field so the delta is attributable. */
function floorCandidate(over: Partial<BirthdayVenueCandidate> = {}): BirthdayVenueCandidate {
  return {
    venueId: "v1",
    category: "restaurant",
    distanceMeters: 10000,
    reachMeters: 10000,
    liveContentTypes: 0,
    activeCampaigns: 0,
    boosted: false,
    ...over,
  };
}

describe("birthday ranking — weights", () => {
  test("the four weights sum to exactly the total — no float slack", () => {
    const sum =
      BIRTHDAY_WEIGHTS.proximity +
      BIRTHDAY_WEIGHTS.richness +
      BIRTHDAY_WEIGHTS.campaigns +
      BIRTHDAY_WEIGHTS.boost;
    // Scores are compared across users; they are only comparable if
    // the scale is the same for everyone. Held as integers precisely
    // so this can be asserted exactly rather than within a tolerance.
    assert.equal(sum, BIRTHDAY_WEIGHT_TOTAL);
  });

  test("the weights are the product-agreed 40/30/20/10", () => {
    assert.deepEqual(BIRTHDAY_WEIGHTS, {
      proximity: 40,
      richness: 30,
      campaigns: 20,
      boost: 10,
    });
  });

  test("a candidate at every floor scores 0, at every ceiling scores 1", () => {
    assert.equal(scoreVenue(floorCandidate()), 0);
    assert.equal(
      scoreVenue(
        floorCandidate({
          distanceMeters: 0,
          liveContentTypes: RICHNESS_TYPES,
          activeCampaigns: ACTIVE_CAMPAIGN_CAP,
          boosted: true,
        }),
      ),
      1,
    );
  });
});

describe("birthday ranking — each dimension carries its own weight", () => {
  test("proximity contributes exactly 0.4 across its range", () => {
    const far = scoreVenue(floorCandidate({ distanceMeters: 10000 }));
    const near = scoreVenue(floorCandidate({ distanceMeters: 0 }));
    assert.equal(near - far, BIRTHDAY_WEIGHTS.proximity / BIRTHDAY_WEIGHT_TOTAL);
  });

  test("richness contributes exactly 0.3 across its range", () => {
    const none = scoreVenue(floorCandidate({ liveContentTypes: 0 }));
    const all = scoreVenue(floorCandidate({ liveContentTypes: RICHNESS_TYPES }));
    assert.equal(all - none, BIRTHDAY_WEIGHTS.richness / BIRTHDAY_WEIGHT_TOTAL);
  });

  test("campaigns contributes exactly 0.2 across its range", () => {
    const none = scoreVenue(floorCandidate({ activeCampaigns: 0 }));
    const full = scoreVenue(floorCandidate({ activeCampaigns: ACTIVE_CAMPAIGN_CAP }));
    assert.equal(full - none, BIRTHDAY_WEIGHTS.campaigns / BIRTHDAY_WEIGHT_TOTAL);
  });

  test("boost contributes exactly 0.1 and is binary", () => {
    const off = scoreVenue(floorCandidate({ boosted: false }));
    const on = scoreVenue(floorCandidate({ boosted: true }));
    assert.equal(on - off, BIRTHDAY_WEIGHTS.boost / BIRTHDAY_WEIGHT_TOTAL);
  });
});

describe("birthday ranking — clamping", () => {
  test("a venue past the user's reach scores 0 proximity, never negative", () => {
    // Without the clamp this term goes negative and a distant venue
    // would drag its own score below a venue with nothing at all.
    const beyond = scoreVenue(floorCandidate({ distanceMeters: 90000, reachMeters: 10000 }));
    assert.equal(beyond, 0);
  });

  test("campaigns saturate at the cap — 50 offers score as 5", () => {
    const atCap = scoreVenue(floorCandidate({ activeCampaigns: ACTIVE_CAMPAIGN_CAP }));
    const wayOver = scoreVenue(floorCandidate({ activeCampaigns: 50 }));
    assert.equal(wayOver, atCap);
  });

  test("an unrestricted user falls back to the default reach, not to NaN", () => {
    const candidate = floorCandidate({ distanceMeters: PROXIMITY_DEFAULT_REACH_M / 2, reachMeters: undefined });
    const score = scoreVenue(candidate);
    assert.ok(Number.isFinite(score));
    // Half the default reach ⇒ half the proximity weight.
    assert.equal(score, BIRTHDAY_WEIGHTS.proximity / BIRTHDAY_WEIGHT_TOTAL / 2);
  });

  test("a zero reach yields no proximity signal instead of a divide-by-zero", () => {
    const score = scoreVenue(floorCandidate({ distanceMeters: 0, reachMeters: 0 }));
    assert.ok(Number.isFinite(score));
    assert.equal(score, 0);
  });
});

describe("birthday ranking — ordering", () => {
  test("higher score comes first", () => {
    const ranked = rankCandidates([
      floorCandidate({ venueId: "far" }),
      floorCandidate({ venueId: "near", distanceMeters: 0 }),
    ]);
    assert.deepEqual(ranked.map((r) => r.venueId), ["near", "far"]);
  });

  test("equal scores break on distance, then on venueId — same order every run", () => {
    // Same score (both at the floor), same distance: only the id can
    // decide, and it must decide the same way twice or a retry of the
    // same day produces a different notification body.
    const input = [floorCandidate({ venueId: "b" }), floorCandidate({ venueId: "a" })];
    assert.deepEqual(rankCandidates(input).map((r) => r.venueId), ["a", "b"]);
    assert.deepEqual(rankCandidates([...input].reverse()).map((r) => r.venueId), ["a", "b"]);
  });
});

describe("birthday ranking — distinct categories", () => {
  const ranked = [
    { venueId: "r1", category: "restaurant" },
    { venueId: "r2", category: "restaurant" },
    { venueId: "c1", category: "cinema" },
    { venueId: "r3", category: "restaurant" },
    { venueId: "s1", category: "spa" },
    { venueId: "k1", category: "karaoke" },
  ];

  test("takes the best of each category, in rank order", () => {
    assert.deepEqual(
      pickDistinctCategoryVenues(ranked).map((v) => v.venueId),
      ["r1", "c1", "s1"],
    );
  });

  test("stops at the highlight count even when more categories exist", () => {
    assert.equal(pickDistinctCategoryVenues(ranked).length, BIRTHDAY_HIGHLIGHT_COUNT);
  });

  test("returns fewer than three rather than repeating a category", () => {
    // Three restaurants is one suggestion said three times. The rule
    // is to send two, or one, not to pad.
    const oneCategory = [
      { venueId: "r1", category: "restaurant" },
      { venueId: "r2", category: "restaurant" },
      { venueId: "r3", category: "restaurant" },
    ];
    assert.deepEqual(pickDistinctCategoryVenues(oneCategory).map((v) => v.venueId), ["r1"]);

    const twoCategories = [...oneCategory, { venueId: "c1", category: "cinema" }];
    assert.deepEqual(pickDistinctCategoryVenues(twoCategories).map((v) => v.venueId), ["r1", "c1"]);
  });

  test("an empty pool picks nothing — no notification is sent that day", () => {
    assert.deepEqual(pickDistinctCategoryVenues([]), []);
  });
});

describe("birthday ranking — constants", () => {
  test("the feed holds more than the notification names", () => {
    // The push names three; the list is what the person opens. If
    // these were equal the list would add nothing to the push.
    assert.ok(BIRTHDAY_FEED_MAX > BIRTHDAY_HIGHLIGHT_COUNT);
  });

  test("richness counts exactly the three content kinds that exist", () => {
    // offer, event, pinbox — the same three `IntentType` covers.
    assert.equal(RICHNESS_TYPES, 3);
  });
});
