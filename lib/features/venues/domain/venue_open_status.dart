import 'entities/venue.dart';

/// Pure, client-side open/closed computation from a venue's stored
/// [OpeningHours] — no external API, no fabricated status. Handles
/// overnight ranges (e.g. a bar open 22:00→03:00) by also checking
/// whether "now" falls before yesterday's closing time.
bool isVenueOpenNow(OpeningHours hours, DateTime now) {
  if (hours.is24h) return true;

  final nowMinutes = now.hour * 60 + now.minute;

  if (_isWithinDay(hours.schedule[now.weekday], nowMinutes)) return true;

  final yesterday = now.weekday == DateTime.monday
      ? DateTime.sunday
      : now.weekday - 1;
  final yesterdayHours = hours.schedule[yesterday];
  if (yesterdayHours != null) {
    final open = _minutesOf(yesterdayHours.open);
    final close = _minutesOf(yesterdayHours.close);
    // Only relevant if yesterday's range spans past midnight.
    if (open != null && close != null && close <= open && nowMinutes < close) {
      return true;
    }
  }

  return false;
}

bool _isWithinDay(DayHours? today, int nowMinutes) {
  if (today == null) return false;
  final open = _minutesOf(today.open);
  final close = _minutesOf(today.close);
  if (open == null || close == null) return false;

  if (close > open) {
    // Normal same-day range.
    return nowMinutes >= open && nowMinutes < close;
  }
  // Overnight range — open until midnight, the rest is picked up by
  // [isVenueOpenNow]'s "yesterday" check on the following day.
  return nowMinutes >= open;
}

int? _minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}
