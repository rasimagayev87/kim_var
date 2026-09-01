import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Instagram-style relative timestamp ("2 saat əvvəl", "3 gün əvvəl"),
/// computed live from the real [dateTime] — never a hardcoded string.
/// Falls back to an absolute date once a post is old enough that a
/// relative label would stop being useful (28+ days).
String formatRelativeTime(DateTime dateTime, AppLocalizations loc) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return loc.postTimeJustNow;
  if (diff.inMinutes < 60) return loc.postTimeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return loc.postTimeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return loc.postTimeDaysAgo(diff.inDays);
  if (diff.inDays < 28) return loc.postTimeWeeksAgo(diff.inDays ~/ 7);
  return DateFormat('d MMM').format(dateTime);
}

/// WhatsApp-style "Son görülmə" timestamp — deliberately NOT
/// [formatRelativeTime]'s Instagram-style "X saat əvvəl" for anything
/// same-day, since a same-day last-seen reads far more usefully as a
/// clock time ("bugün 18:05") than as an ever-changing "3 saat əvvəl"
/// that forces the reader to do math. Only falls back to a day-count
/// once the exact time is no longer the useful part of the answer.
String formatLastSeen(DateTime dateTime, AppLocalizations loc) {
  final now = DateTime.now();
  final time = DateFormat('HH:mm').format(dateTime);

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  if (isSameDay(dateTime, now)) return '${loc.chatDateToday} $time';
  if (isSameDay(dateTime, now.subtract(const Duration(days: 1))))
    return '${loc.chatDateYesterday} $time';

  final diff = now.difference(dateTime);
  if (diff.inDays < 7) return loc.postTimeDaysAgo(diff.inDays);
  return DateFormat('d MMM').format(dateTime);
}
