import '../../l10n/app_localizations.dart';
import 'distance_unit.dart';

/// Single source of truth for turning a raw meters distance into
/// localized display text, respecting the user's Xəritə və Lokasiya →
/// Məsafə vahidi preference. Used everywhere a distance is shown
/// (discover map/cards, user profile) so the unit choice is honored
/// consistently across the app rather than only on one screen.
String formatDistance(AppLocalizations loc, double meters, DistanceUnit unit) {
  if (unit == DistanceUnit.mi) {
    final miles = meters / 1609.344;
    return loc.distanceMilesAway(miles.toStringAsFixed(miles < 10 ? 1 : 0));
  }
  return meters < 1000 ? loc.distanceMetersAway(meters.round()) : loc.distanceKmAway((meters / 1000).toStringAsFixed(1));
}
