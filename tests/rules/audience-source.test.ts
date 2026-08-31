// «Ətrafınızda» mənbəyi — kod səviyyəsində qoruma.
//
// Canlı tab uzun müddət `activeCheckinCount` oxuyurdu, yəni könüllü
// check-in sayını «ətrafınızdakı insanlar» adı altında göstərirdi.
// Bu test həmin qarışıqlığın geri qayıtmasını çətinləşdirir.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const service = readFileSync(join(here, "../../lib/features/live_feed/data/live_feed_service.dart"), "utf8");

/** `audienceItemsFrom` funksiyasının gövdəsi. */
function audienceBody(): string {
  const start = service.indexOf("List<LiveFeedItem> audienceItemsFrom(");
  assert.ok(start > 0, "audienceItemsFrom tapılmadı");
  const rest = service.slice(start);
  return rest.slice(0, rest.indexOf("\n  }\n") + 4);
}

describe("Canlı tab — audience mənbəyi", () => {
  test("audience funksiyası activeCheckinCount OXUMUR", () => {
    assert.equal(
      audienceBody().includes("activeCheckinCount"),
      false,
      "«Ətrafınızda» yenidən check-in sayını oxuyur — bu, düzəldilmiş qarışıqlıqdır",
    );
  });

  test("audience funksiyası currentAudienceCount oxuyur", () => {
    assert.match(audienceBody(), /currentAudienceCount/);
  });

  test("köhnəlik yoxlaması var", () => {
    // Dəyər 15 dəqiqəlik anlıq şəkildir; planlaşdırılmış funksiya
    // dayanarsa rəqəm yox olmalıdır, köhnəlməməlidir.
    assert.match(audienceBody(), /staleAfter/);
  });

  test("k-anonimlik filtri var — server 0 yazır, client 0-ı göstərmir", () => {
    assert.match(audienceBody(), /currentAudienceCount > 0/);
  });

  test("boş yer bölməsi hələ də availableSeats oxuyur (qarışmayıb)", () => {
    const start = service.indexOf("List<LiveFeedItem> seatAvailableItemsFrom(");
    assert.ok(start > 0);
    const body = service.slice(start, start + 900);
    assert.match(body, /availableSeats/);
    assert.equal(body.includes("activeCheckinCount"), false);
    assert.equal(body.includes("currentAudienceCount"), false);
  });
});

describe("məkan profili — check-in mənbəyi", () => {
  const ds = readFileSync(
    join(here, "../../lib/features/venues/data/datasources/firebase_venue_remote_datasource.dart"),
    "utf8",
  );

  test("profil sayğacı visibleCheckinCount oxuyur, xam sahəni yox", () => {
    const start = ds.indexOf("Stream<int> watchActiveCheckinCount(");
    assert.ok(start > 0);
    const body = ds.slice(start, start + 1400);
    assert.match(body, /visibleCheckinCount/);
    assert.equal(
      /\\['activeCheckinCount'\\]/.test(body),
      false,
      "profil yenidən xam sayğacı oxuyur",
    );
  });
});
