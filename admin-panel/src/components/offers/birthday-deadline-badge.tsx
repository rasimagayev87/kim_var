"use client";

import { useEffect, useState } from "react";

import { birthdayDeadlineState, formatBirthdayDeadline } from "@/lib/birthday-deadline";

/**
 * The "🎂 Ad günü — 13:00-a 47 dəqiqə" marker in the offers queue.
 *
 * A CLIENT component, and it has to be: the page is server-rendered and
 * cached, so a countdown baked in at render time would sit frozen at
 * whatever it said when the page was built. A moderator leaving the tab
 * open would read "45 dəqiqə" an hour after the deadline passed —
 * worse than no badge, because it would actively say there is time.
 *
 * Re-reads the clock every 30 seconds, so the displayed minute is never
 * more than a minute stale.
 */
export function BirthdayDeadlineBadge({ matchId }: { matchId: string | null }) {
  const [now, setNow] = useState<Date | null>(null);

  useEffect(() => {
    // Set inside the effect, never during render: the server and the
    // client would otherwise disagree about the time and React would
    // report a hydration mismatch on every birthday row.
    setNow(new Date());
    const timer = setInterval(() => setNow(new Date()), 30_000);
    return () => clearInterval(timer);
  }, []);

  if (now === null) return null;
  const state = birthdayDeadlineState(matchId, now);
  const label = formatBirthdayDeadline(state);
  if (label === null) return null;

  return (
    <span
      className={
        state.kind === "missed"
          ? "mt-1 inline-flex w-fit items-center rounded-full bg-muted px-2 py-0.5 text-[11px] font-medium text-muted-foreground"
          : // Deliberately loud. This is the one row in the queue with a
            // deadline, and the point is that it does not look like the
            // others.
            "mt-1 inline-flex w-fit items-center rounded-full bg-pink-100 px-2 py-0.5 text-[11px] font-semibold text-pink-700"
      }
    >
      {label}
    </span>
  );
}
