import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../venues/domain/entities/venue.dart'
    show TimestampConverter, VenueCategory, VenueCategoryConverter;

part 'venue_event.freezed.dart';
part 'venue_event.g.dart';

/// Preset categories from the create form's dropdown — plain enum
/// rather than reusing [VenueCategory] since an event's category is
/// about what KIND of happening it is (music night, tasting…), not
/// what kind of venue is hosting it.
enum VenueEventCategory { music, tasting, themeNight, other }

class VenueEventCategoryConverter
    implements JsonConverter<VenueEventCategory, String?> {
  const VenueEventCategoryConverter();

  @override
  VenueEventCategory fromJson(String? json) =>
      VenueEventCategory.values.firstWhere(
        (c) => c.name == json,
        orElse: () => VenueEventCategory.other,
      );

  @override
  String toJson(VenueEventCategory category) => category.name;
}

/// `pending` → `upcoming` → `live` → `ended`.
///
/// Every event is CREATED as `pending` — `firestore.rules` accepts no
/// other value from a client. `onVenueEventCreated` then decides in a
/// transaction: a venue that has already published
/// `EVENT_TRUST_THRESHOLD` events goes straight to `upcoming` (a
/// sub-second hop nobody but the owner sees), a newer one waits for a
/// moderator. The transaction is the point — a rule reading a counter
/// could not stop ten events being created before the first increment
/// landed.
///
/// `upcoming` → `live` → `ended` stays fully automatic, driven by
/// [VenueEvent.startAt]/[endAt] (`advanceVenueEventStatuses`).
///
/// `rejected` is a moderator's decision OR the automatic outcome when a
/// `pending` event reaches its own `startAt` — publishing an event that
/// has already begun is worse than not publishing it, so the owner is
/// notified instead and can re-create it.
///
/// `cancelled` is the one state the owner can set directly.
enum VenueEventStatus { pending, upcoming, live, ended, cancelled, rejected }

/// Events a venue may publish per subscription period — mirrors
/// `FREE_EVENTS_PER_PERIOD` in functions/src/index.ts.
///
/// Flat across every tier, unlike the campaign quota, because there is
/// no paid path behind it: exceeding it blocks rather than charges, and
/// a tiered block would be a tiered CAP rather than a tiered allowance.
const int kFreeEventsPerPeriod = 5;

/// Events a venue must publish before its events stop being reviewed —
/// mirrors `EVENT_TRUST_THRESHOLD`.
const int kEventTrustThreshold = 3;

class VenueEventStatusConverter
    implements JsonConverter<VenueEventStatus, String?> {
  const VenueEventStatusConverter();

  @override
  VenueEventStatus fromJson(String? json) =>
      // Unknown/absent falls back to `pending`, the state that shows
      // NOTHING publicly. The previous default was `upcoming`, which
      // meant a malformed document was treated as published.
      VenueEventStatus.values.firstWhere(
        (s) => s.name == json,
        orElse: () => VenueEventStatus.pending,
      );

  @override
  String toJson(VenueEventStatus status) => status.name;
}

/// A venue owner's one-off "gəlmək üçün səbəb" announcement.
///
/// Trust-based moderation: a venue's first [kEventTrustThreshold]
/// events are reviewed, everything after publishes on creation. Events
/// were previously auto-approved outright, which made them the only
/// listing that could reach the daily digest push with no review and no
/// payment behind it — while blanket pre-moderation would break the
/// "tonight at 21:00" case that events exist for.
///
/// [venueName]/[venuePhotoUrl]/[venueCategory]/[lat]/[lng] are
/// denormalized from the venue at creation time, same reasoning as the
/// identical fields on `Offer` — the merged Kəşf et → Təkliflər list
/// (offers + events + PinBox, sorted together) needs venue identity on
/// every card without an N+1 join back to `venues/{venueId}` per item.
/// [venueCategory] specifically exists so the Fürsətlər filter sheet's
/// category chip (a [VenueCategory], NOT a [VenueEventCategory]) can
/// filter events the same way it filters offers/PinBox — see
/// `VenueEventRepository.fetchEventsWithinRadius`'s `category` param.
/// A legacy event written before this field existed decodes it as
/// [VenueCategory.other] (see [VenueCategoryConverter]'s `orElse`), not
/// a crash — `admin-panel/scripts/backfill-event-venue-categories.ts`
/// fixes those up from each event's own venue doc.
@freezed
class VenueEvent with _$VenueEvent {
  const VenueEvent._();

  const factory VenueEvent({
    required String id,
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    @VenueCategoryConverter()
    @Default(VenueCategory.other)
    VenueCategory venueCategory,
    required double lat,
    required double lng,
    required String title,
    required String description,
    String? coverImageUrl,
    @TimestampConverter() required DateTime startAt,
    @TimestampConverter() required DateTime endAt,
    @VenueEventCategoryConverter()
    @Default(VenueEventCategory.other)
    VenueEventCategory category,
    @VenueEventStatusConverter()
    @Default(VenueEventStatus.pending)
    VenueEventStatus status,

    /// Why an event was rejected — a moderator's note, or the automatic
    /// one written when a `pending` event reached its own `startAt`
    /// before anyone reviewed it. Shown on the owner's own card,
    /// because that rejection is the product's delay rather than the
    /// owner's mistake and they can only act on it if they are told.
    String? reviewNote,
    @TimestampConverter() required DateTime createdAt,
  }) = _VenueEvent;

  factory VenueEvent.fromJson(Map<String, dynamic> json) =>
      _$VenueEventFromJson(json);

  factory VenueEvent.fromFirestore(String id, Map<String, dynamic> data) {
    return VenueEvent.fromJson({...data, 'id': id});
  }

  /// Today's date (device-local, display purposes only — the actual
  /// upcoming/live/ended transition is server-driven) — powers the
  /// "🎤 Bu axşam: [title]" banner on Discover venue cards, which only
  /// ever shows for an event happening today.
  bool get isToday {
    final now = DateTime.now();
    return startAt.year == now.year &&
        startAt.month == now.month &&
        startAt.day == now.day;
  }
}
