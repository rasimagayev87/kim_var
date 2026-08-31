/**
 * Admin-panel copy of `functions/src/event-urgency.ts`.
 *
 * The two are separate Node projects with no shared package. Held in
 * sync by `tests/rules/event-urgency.test.ts`, which imports BOTH and
 * fails on any disagreement — the same arrangement as `venue-fees.ts`.
 *
 * How close a pending event is to starting.
 *
 * ── Why this needs to be visible at all ────────────────────────────
 *
 * Events are the only listing with a deadline the product cannot move.
 * A campaign sitting in the queue for a day is late; an event sitting
 * there past its own `startAt` is worthless, and gets auto-rejected
 * (`advanceVenueEventStatuses`) because publishing it would announce
 * something that has already begun.
 *
 * The moderation queue therefore has to say how long is left, the same
 * way the birthday queue says how long until 13:00 (`birthday-deadline.ts`).
 * A deadline nobody can see is not a deadline.
 *
 * No SDK imports, so `tests/rules/event-urgency.test.ts` asserts the
 * arithmetic, and the admin panel keeps a twin held in sync by that
 * same test.
 */

/**
 * Inside this window a pending event is URGENT — the queue marks it,
 * and `remindAdminsOfPendingEvents` writes an admin notification.
 *
 * Three hours: long enough that a moderator checking in at the top of
 * the hour still has room to act, short enough that an event created
 * days ahead does not sit permanently flagged and turn the marker into
 * wallpaper.
 */
export const EVENT_URGENT_WINDOW_MS = 3 * 60 * 60 * 1000;

export type EventUrgency =
  | { kind: "none" }
  | { kind: "upcoming"; minutesLeft: number }
  | { kind: "urgent"; minutesLeft: number }
  | { kind: "missed" };

/**
 * What the queue should say about one pending event.
 *
 * `missed` is not "lost work": `advanceVenueEventStatuses` rejects it
 * and tells the owner why, so they can re-create it. The label says
 * that rather than implying the moderator should still approve it —
 * approving a started event is the one action that makes things worse.
 */
export function eventUrgency(
  status: string,
  startAtMs: number | null | undefined,
  now: number = Date.now(),
): EventUrgency {
  if (status !== "pending" || typeof startAtMs !== "number") return { kind: "none" };
  const remainingMs = startAtMs - now;
  if (remainingMs <= 0) return { kind: "missed" };
  // Rounded UP so the last 30 seconds read "1 dəqiqə" rather than "0".
  const minutesLeft = Math.ceil(remainingMs / 60000);
  return remainingMs <= EVENT_URGENT_WINDOW_MS
    ? { kind: "urgent", minutesLeft }
    : { kind: "upcoming", minutesLeft };
}

/** Minutes below an hour, hours and minutes above it — "247 dəqiqə" is
 * a number the reader has to convert before it means anything. */
export function formatEventUrgency(urgency: EventUrgency): string | null {
  if (urgency.kind === "none") return null;
  if (urgency.kind === "missed") return "⏰ Başlama vaxtı keçib — avtomatik rədd ediləcək";
  const { minutesLeft } = urgency;
  const when =
    minutesLeft < 60
      ? `${minutesLeft} dəqiqə`
      : `${Math.floor(minutesLeft / 60)} saat ${minutesLeft % 60} dəqiqə`;
  return `⏰ ${when}yə başlayır`;
}
