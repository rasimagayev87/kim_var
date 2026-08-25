import '../../../events/domain/entities/venue_event.dart';

/// An event belongs in the "Bu axşam" hero when it's either literally
/// happening right now, or scheduled to start this evening (18:00–
/// 00:00) today — a today event that starts earlier (e.g. a lunch
/// event ending by 17:00) belongs in the plain "Tədbirlər" list
/// instead, not the hero. `nearbyEventsProvider` only ever returns
/// `upcoming`/`live` events (`ended`/`cancelled` are filtered
/// server-side, see `fetchEventsWithinRadius`), so this split is all
/// that's needed between [LiveFeedHeroSection] and
/// [LiveFeedEventsSection] — every event lands in exactly one of the
/// two, never both, never neither.
bool isTonightHeroEvent(VenueEvent event) {
  if (event.status == VenueEventStatus.live) return true;
  return event.isToday && event.startAt.hour >= 18;
}
