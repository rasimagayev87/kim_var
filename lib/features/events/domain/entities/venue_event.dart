import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../venues/domain/entities/venue.dart' show TimestampConverter;

part 'venue_event.freezed.dart';
part 'venue_event.g.dart';

/// Preset categories from the create form's dropdown — plain enum
/// rather than reusing [VenueCategory] since an event's category is
/// about what KIND of happening it is (music night, tasting…), not
/// what kind of venue is hosting it.
enum VenueEventCategory { music, tasting, themeNight, other }

class VenueEventCategoryConverter implements JsonConverter<VenueEventCategory, String?> {
  const VenueEventCategoryConverter();

  @override
  VenueEventCategory fromJson(String? json) =>
      VenueEventCategory.values.firstWhere((c) => c.name == json, orElse: () => VenueEventCategory.other);

  @override
  String toJson(VenueEventCategory category) => category.name;
}

/// `upcoming` → `live` → `ended` is fully automatic, driven by
/// [VenueEvent.startAt]/[endAt] (see `advanceVenueEventStatuses`,
/// scheduled Cloud Function) — the owner never sets these directly.
/// `cancelled` is the one state a human (owner, or admin resolving an
/// `eventReports` complaint) can reach at any time.
enum VenueEventStatus { upcoming, live, ended, cancelled }

class VenueEventStatusConverter implements JsonConverter<VenueEventStatus, String?> {
  const VenueEventStatusConverter();

  @override
  VenueEventStatus fromJson(String? json) =>
      VenueEventStatus.values.firstWhere((s) => s.name == json, orElse: () => VenueEventStatus.upcoming);

  @override
  String toJson(VenueEventStatus status) => status.name;
}

/// A venue owner's one-off "gəlmək üçün səbəb" announcement — auto-
/// approved (no admin moderation step, unlike [Venue]/`Offer`, since
/// the venue itself is already verified) and immediately visible +
/// pushed to nearby users the moment it's published. Reported content
/// is handled after the fact via `eventReports`, not gated before
/// publish — see the create screen / Cloud Functions doc comments.
///
/// [venueName]/[venuePhotoUrl]/[lat]/[lng] are denormalized from the
/// venue at creation time, same reasoning as the identical fields on
/// `Offer` — the merged Kəşf et → Təkliflər list (offers + events,
/// sorted together) needs venue identity on every card without an N+1
/// join back to `venues/{venueId}` per item.
@freezed
class VenueEvent with _$VenueEvent {
  const VenueEvent._();

  const factory VenueEvent({
    required String id,
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double lat,
    required double lng,
    required String title,
    required String description,
    String? coverImageUrl,
    @TimestampConverter() required DateTime startAt,
    @TimestampConverter() required DateTime endAt,
    @VenueEventCategoryConverter() @Default(VenueEventCategory.other) VenueEventCategory category,
    @VenueEventStatusConverter() @Default(VenueEventStatus.upcoming) VenueEventStatus status,
    @TimestampConverter() required DateTime createdAt,
  }) = _VenueEvent;

  factory VenueEvent.fromJson(Map<String, dynamic> json) => _$VenueEventFromJson(json);

  factory VenueEvent.fromFirestore(String id, Map<String, dynamic> data) {
    return VenueEvent.fromJson({...data, 'id': id});
  }

  /// Today's date (device-local, display purposes only — the actual
  /// upcoming/live/ended transition is server-driven) — powers the
  /// "🎤 Bu axşam: [title]" banner on Discover venue cards, which only
  /// ever shows for an event happening today.
  bool get isToday {
    final now = DateTime.now();
    return startAt.year == now.year && startAt.month == now.month && startAt.day == now.day;
  }
}
