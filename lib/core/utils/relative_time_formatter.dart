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
