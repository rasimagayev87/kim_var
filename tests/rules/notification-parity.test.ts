/**
 * Server ↔ Dart parity for notification types.
 *
 * ── Why this file exists ───────────────────────────────────────────
 *
 * `notifyUser` does NOT persist `title`/`body` — they go into the FCM
 * payload only. The in-app feed rebuilds the text from `type` +
 * `metadata` via `notification_localizer.dart`. So a type the server
 * sends but Dart does not know resolves to `NotificationType.other`,
 * the localizer returns null, and the feed renders a BLANK CARD.
 *
 * The push looks perfect. The card is empty. Nothing fails, nothing
 * logs, and it is invisible until somebody opens the app and sees a
 * row with no text.
 *
 * This has now happened twice:
 *
 *   1. The three daily digest types (`dailyOffersDigest`,
 *      `dailyPinboxDigest`, `dailyEventsDigest`) shipped with no Dart
 *      side at all and rendered blank for everyone who received one.
 *   2. `eventApproved`/`eventRejected` repeated it, added hours after
 *      the first was fixed, in the same working session.
 *
 * Twice is a pattern, and a pattern with no test is a third occurrence
 * waiting. `notification-categories.test.ts` parses the SERVER only —
 * it verifies the category map matches the call sites and has nothing
 * to say about Dart. This file is the other half.
 *
 * It parses both sides as TEXT rather than importing them, because
 * Dart cannot be imported here — the same arrangement
 * `venue-categories.test.ts` uses for its three copies.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";
import { readFileSync } from "node:fs";

import { NOTIFICATION_CATEGORY_BY_TYPE } from "../../functions/src/notification-categories";

const read = (rel: string) => readFileSync(new URL(rel, import.meta.url), "utf8");

/**
 * Every notification type ANYTHING sends, from BOTH senders.
 *
 * There are two, and missing the second is easy: Cloud Functions send
 * through `notifyUser` (covered by `NOTIFICATION_CATEGORY_BY_TYPE`,
 * which `notification-categories.test.ts` proves matches its call
 * sites), and the ADMIN PANEL sends broadcasts directly
 * (`admin-panel/src/lib/actions/broadcast.ts` — `announcement`,
 * `promotion`, `system`). A broadcast type absent from the Dart side
 * renders exactly the same blank card, and an audit that only read
 * `functions/` would never see it.
 */
const BROADCAST_TYPES = (() => {
  const src = read("../../admin-panel/src/lib/actions/broadcast.ts");
  const m = /export type BroadcastType = ([^;]+);/.exec(src);
  assert.ok(m, "BroadcastType tapılmadı — broadcast.ts dəyişib?");
  return [...m[1].matchAll(/"([a-z]+)"/g)].map((x) => x[1]);
})();

/**
 * The admin panel's OTHER notification writer.
 *
 * `sendBroadcast` is not the only one — `warnUser` in
 * `lib/actions/users.ts` writes straight into
 * `users/{uid}/notifications` with `type: "warning"`. That was a third
 * producer nobody had catalogued, and this test is how it surfaced.
 *
 * Scans every file that writes to a `notifications` collection rather
 * than naming the two known files, so a fourth writer is caught the
 * day it appears instead of the day a user reports a blank card.
 */
const ADMIN_DIRECT_TYPES = (() => {
  const files = ["../../admin-panel/src/lib/actions/users.ts"];
  const found = new Set<string>();
  for (const f of files) {
    const src = read(f);
    for (const m of src.matchAll(/collection\("notifications"\)[\s\S]{0,400}?type:\s*"([a-zA-Z]+)"/g)) {
      found.add(m[1]);
    }
  }
  return [...found];
})();

const SERVER_TYPES = [
  ...new Set([...Object.keys(NOTIFICATION_CATEGORY_BY_TYPE), ...BROADCAST_TYPES, ...ADMIN_DIRECT_TYPES]),
].sort();

/** `NotificationType` enum members, excluding the `other` fallback. */
function dartEnumTypes(): string[] {
  const src = read("../../lib/features/notifications/domain/entities/notification.dart");
  const start = src.indexOf("enum NotificationType");
  // NOT `indexOf("}")` — the members carry doc comments containing
  // things like `birthdayMatches/{date}_{venueId}`, and the first `}`
  // lands inside one of them. `other,` is the enum's last member.
  const end = src.indexOf("  other,", start);
  assert.ok(end > start, "NotificationType enum-unun sonu tapılmadı");
  const body = src.slice(start, end);
  return [...body.matchAll(/^\s{2}([a-z][A-Za-z0-9]*),/gm)].map((m) => m[1]).filter((t) => t !== "other");
}

/** Types the localizer has a `case` for. */
function localizedTypes(): string[] {
  const src = read("../../lib/features/notifications/presentation/notification_localizer.dart");
  return [...src.matchAll(/case NotificationType\.([A-Za-z0-9]+):/g)].map((m) => m[1]);
}

/** Types with an icon in the feed. */
function icontypes(): string[] {
  const src = read("../../lib/features/notifications/presentation/screens/notifications_feed_screen.dart");
  return [...src.matchAll(/NotificationType\.([A-Za-z0-9]+):\s*Icons\./g)].map((m) => m[1]);
}

/** `targetType` strings the navigator can route. */
function routedTargetTypes(): string[] {
  const src = read("../../lib/features/notifications/presentation/notification_navigation.dart");
  return [
    ...[...src.matchAll(/case '([a-z_]+)':/g)].map((m) => m[1]),
    ...[...src.matchAll(/targetType == '([a-z_]+)'/g)].map((m) => m[1]),
  ];
}

/**
 * Every `targetType:` the server passes to **`notifyUser`**.
 *
 * `notifyAdmins` also takes a `targetType`, and those route in the
 * ADMIN PANEL, not in the app — `events`, `offers`, `payment`,
 * `review`, `user`. Matching on the bare field name would report all
 * five as unrouted app destinations, which is why this walks each call
 * expression and keeps only the `notifyUser` ones.
 */
function serverTargetTypes(): string[] {
  const src = read("../../functions/src/index.ts");
  const found = new Set<string>();
  for (const m of src.matchAll(/notifyUser\(\{/g)) {
    // The call's own object literal, bounded by the next `});` — long
    // enough for the longest call site, short enough not to run into
    // the following function.
    const chunk = src.slice(m.index!, src.indexOf("});", m.index!) + 3);
    for (const t of chunk.matchAll(/targetType:\s*"([a-z_]+)"/g)) found.add(t[1]);
    // Ternary form: `targetType: single ? "a" : "b"`.
    for (const t of chunk.matchAll(/targetType:\s*[^,\n]*\?\s*"([a-z_]+)"\s*:\s*"([a-z_]+)"/g)) {
      found.add(t[1]);
      found.add(t[2]);
    }
  }
  return [...found].sort();
}

describe("PARİTET — server göndərir, Dart tanıyır", () => {
  test("hər server tipi Dart enum-undadır", () => {
    const missing = SERVER_TYPES.filter((t) => !dartEnumTypes().includes(t));
    assert.deepEqual(
      missing,
      [],
      `Bu tiplər serverdə göndərilir, amma NotificationType enum-unda YOXDUR: ${missing.join(", ")}\n` +
        "Nəticə: notificationTypeFromString onları `other`-ə salır, localizer null qaytarır, " +
        "və lentdə BOŞ KART görünür. Push düzgün gəlir — səhv yalnız tətbiq açılanda görünür.",
    );
  });

  test("hər server tipinin localizer-də `case`-i var", () => {
    const missing = SERVER_TYPES.filter((t) => !localizedTypes().includes(t));
    assert.deepEqual(
      missing,
      [],
      `Localizer-də case olmayan tiplər: ${missing.join(", ")}\n` +
        "Enum-a əlavə etmək kifayət deyil — mətn buradan gəlir.",
    );
  });

  test("hər server tipinin lentdə öz ikonu var", () => {
    // Kosmetikdir, sınıqlıq deyil — `_notificationIcons[type] ??
    // Icons.notifications` fallback-i var. Amma "VIP aktivləşdi" üçün
    // ümumi zəng ikonu səhv siqnaldır, və bu testsiz heç kim fərqi
    // görməzdi.
    const missing = SERVER_TYPES.filter((t) => !icontypes().includes(t));
    assert.deepEqual(missing, [], `Lentdə öz ikonu olmayan tiplər: ${missing.join(", ")}`);
  });
});

describe("PARİTET — naviqasiya", () => {
  test("serverin göndərdiyi hər targetType marşrutlaşdırıla bilir", () => {
    const routed = routedTargetTypes();
    const missing = serverTargetTypes().filter((t) => !routed.includes(t));
    assert.deepEqual(
      missing,
      [],
      `Bu targetType-lar serverdən göndərilir, amma notification_navigation.dart onları tanımır: ` +
        `${missing.join(", ")}\nNəticə: istifadəçi bildirişə toxunur və HEÇ NƏ olmur.`,
    );
  });
});

describe("PARİTET — əks istiqamət", () => {
  test("Dart enum-unda serverin heç vaxt göndərmədiyi tip varsa, o, sənədləşdirilib", () => {
    // Retired types stay in the enum on purpose so notifications
    // already sitting in users' feeds keep rendering. They must say so
    // in a comment, otherwise a stale enum member and a forgotten one
    // look identical.
    const src = read("../../lib/features/notifications/domain/entities/notification.dart");
    const orphans = dartEnumTypes().filter((t) => !SERVER_TYPES.includes(t));
    for (const t of orphans) {
      const i = src.indexOf(`  ${t},`);
      const preceding = src.slice(Math.max(0, i - 900), i);
      assert.ok(
        /RETIRED|retired|artıq göndərilmir|nothing sends/i.test(preceding),
        `\`${t}\` Dart enum-undadır, amma server onu göndərmir və səbəbi yazılmayıb. ` +
          "Köhnəlmiş tip qəsdən saxlanılırsa şərhdə RETIRED yazılmalıdır.",
      );
    }
  });
});
