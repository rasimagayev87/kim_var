/**
 * The events queue's countdown (`functions/src/event-urgency.ts`).
 *
 * An event is the only listing with a deadline the product cannot
 * move: past its own `startAt` a pending event is auto-rejected,
 * because publishing something that has already begun is worse than
 * publishing nothing. The queue's whole job is to make that visible in
 * time, so the boundaries are worth pinning.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  EVENT_URGENT_WINDOW_MS,
  eventUrgency,
  formatEventUrgency,
} from "../../functions/src/event-urgency";
import {
  EVENT_URGENT_WINDOW_MS as adminWindow,
  eventUrgency as adminUrgency,
  formatEventUrgency as adminFormat,
} from "../../admin-panel/src/lib/event-urgency";

const NOW = Date.parse("2026-09-01T12:00:00Z");
const inMinutes = (m: number) => NOW + m * 60_000;

describe("yalnız `pending` tədbir nişan alır", () => {
  for (const status of ["upcoming", "live", "ended", "cancelled", "rejected"]) {
    test(`"${status}" statusunda nişan yoxdur`, () => {
      // Yayımlanmış tədbirin geri sayımı mənasızdır — moderatorun
      // görməli olduğu yeganə şey baxış gözləyəndir.
      assert.deepEqual(eventUrgency(status, inMinutes(30), NOW), { kind: "none" });
    });
  }

  test("startAt yoxdursa nişan yoxdur, çökmə yox", () => {
    assert.deepEqual(eventUrgency("pending", null, NOW), { kind: "none" });
    assert.deepEqual(eventUrgency("pending", undefined, NOW), { kind: "none" });
  });
});

describe("təcililik həddi", () => {
  test("pəncərədən kənar — `upcoming`", () => {
    const state = eventUrgency("pending", NOW + EVENT_URGENT_WINDOW_MS + 60_000, NOW);
    assert.equal(state.kind, "upcoming");
  });

  test("tam pəncərə sərhədində — hələ `urgent`", () => {
    const state = eventUrgency("pending", NOW + EVENT_URGENT_WINDOW_MS, NOW);
    assert.equal(state.kind, "urgent");
  });

  test("pəncərə daxilində — `urgent`", () => {
    const state = eventUrgency("pending", inMinutes(45), NOW);
    assert.deepEqual(state, { kind: "urgent", minutesLeft: 45 });
  });

  test("başlama vaxtı keçib — `missed`", () => {
    assert.deepEqual(eventUrgency("pending", NOW - 1, NOW), { kind: "missed" });
  });

  test("tam startAt anı artıq keçmiş sayılır", () => {
    assert.deepEqual(eventUrgency("pending", NOW, NOW), { kind: "missed" });
  });

  test("son 30 saniyə `0 dəqiqə` yox, `1 dəqiqə` yazır", () => {
    const state = eventUrgency("pending", NOW + 30_000, NOW);
    assert.deepEqual(state, { kind: "urgent", minutesLeft: 1 });
  });
});

describe("mətn", () => {
  test("bir saatdan az — dəqiqə ilə", () => {
    assert.equal(formatEventUrgency(eventUrgency("pending", inMinutes(45), NOW)), "⏰ 45 dəqiqəyə başlayır");
  });

  test("bir saatdan çox — saat + dəqiqə", () => {
    assert.equal(
      formatEventUrgency(eventUrgency("pending", inMinutes(135), NOW)),
      "⏰ 2 saat 15 dəqiqəyə başlayır",
    );
  });

  test("keçmiş tədbir avtomatik rəddi bildirir", () => {
    // Moderator "hələ təsdiqləyim" düşünməməlidir — başlamış tədbiri
    // təsdiqləmək vəziyyəti daha da pisləşdirən yeganə əməliyyatdır.
    assert.match(formatEventUrgency(eventUrgency("pending", NOW - 1, NOW))!, /avtomatik rədd/);
  });

  test("nişansız hal null qaytarır", () => {
    assert.equal(formatEventUrgency({ kind: "none" }), null);
  });
});

describe("admin panel nüsxəsi ilə paritet", () => {
  test("pəncərə eynidir", () => {
    assert.equal(EVENT_URGENT_WINDOW_MS, adminWindow);
  });

  test("hesablama və mətn eynidir", () => {
    for (const minutes of [-5, 0, 1, 45, 180, 181, 1000]) {
      const at = inMinutes(minutes);
      assert.deepEqual(adminUrgency("pending", at, NOW), eventUrgency("pending", at, NOW), `${minutes} dəq`);
      assert.equal(adminFormat(adminUrgency("pending", at, NOW)), formatEventUrgency(eventUrgency("pending", at, NOW)));
    }
  });
});

describe("server sabiti ilə paritet", () => {
  test("etimad həddi Dart tərəfdə eynidir", async () => {
    const { readFileSync } = await import("node:fs");
    const ts = readFileSync(new URL("../../functions/src/index.ts", import.meta.url), "utf8");
    const dart = readFileSync(
      new URL("../../lib/features/events/domain/entities/venue_event.dart", import.meta.url), "utf8");

    const tsThreshold = /const EVENT_TRUST_THRESHOLD = (\d+);/.exec(ts);
    const dartThreshold = /const int kEventTrustThreshold = (\d+);/.exec(dart);
    assert.ok(tsThreshold && dartThreshold);
    assert.equal(Number(tsThreshold[1]), Number(dartThreshold[1]));

    const tsQuota = /const FREE_EVENTS_PER_PERIOD = (\d+);/.exec(ts);
    const dartQuota = /const int kFreeEventsPerPeriod = (\d+);/.exec(dart);
    assert.ok(tsQuota && dartQuota);
    assert.equal(Number(tsQuota[1]), Number(dartQuota[1]));
    assert.equal(Number(tsQuota[1]), 5, "məhsul qərarı: dövr başına 5 tədbir");
  });
});
