/**
 * "PinBox Öhdəlikləri" is only settled by hand on the last calendar day
 * of each month — throughout the month, obligations just accrue as
 * `pending`. Azerbaijan doesn't observe DST, so a fixed UTC+4 offset is
 * exact (not an approximation) for "today" in Baku, regardless of where
 * this runs (Vercel's Node runtime is UTC).
 */
export function isLastDayOfBakuMonth(now: Date = new Date()): boolean {
  const BAKU_OFFSET_MS = 4 * 60 * 60 * 1000;
  const baku = new Date(now.getTime() + BAKU_OFFSET_MS);
  const year = baku.getUTCFullYear();
  const month = baku.getUTCMonth();
  const day = baku.getUTCDate();
  const lastDayOfMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return day === lastDayOfMonth;
}
