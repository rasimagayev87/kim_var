"use client";

import { useEffect, useState } from "react";

import { eventUrgency, formatEventUrgency } from "@/lib/event-urgency";

/**
 * "⏰ 2 saat 15 dəqiqəyə başlayır" on a pending event.
 *
 * A CLIENT component, and it has to be: the page is server-rendered, so
 * a countdown baked in at render time would sit frozen. A moderator
 * with the tab open would read "2 saat" long after the event started —
 * worse than no badge, because it would actively say there is time.
 *
 * Re-reads the clock every 30 seconds.
 */
export function EventUrgencyBadge({ status, startAt }: { status: string; startAt: string | null }) {
  const [now, setNow] = useState<number | null>(null);

  useEffect(() => {
    // Inside the effect, never during render — the server and the
    // client would otherwise disagree about the time and React would
    // report a hydration mismatch on every pending row.
    setNow(Date.now());
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(timer);
  }, []);

  if (now === null) return null;
  const urgency = eventUrgency(status, startAt ? Date.parse(startAt) : null, now);
  const label = formatEventUrgency(urgency);
  if (label === null) return null;

  const tone =
    urgency.kind === "missed"
      ? "bg-muted text-muted-foreground"
      : urgency.kind === "urgent"
        // Deliberately loud. Inside this window the event is hours from
        // being auto-rejected, and that is the only thing on the page
        // that cannot wait until tomorrow.
        ? "bg-red-100 text-red-700"
        : "bg-amber-50 text-amber-700";

  return (
    <span className={`mt-1 inline-flex w-fit items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ${tone}`}>
      {label}
    </span>
  );
}
