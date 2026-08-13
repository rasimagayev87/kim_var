import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../venues/domain/entities/venue.dart'
    show VenueCategory, VenueCategoryConverter, TimestampConverter, NullableTimestampConverter;

part 'offer.freezed.dart';
part 'offer.g.dart';

/// Matches the Create Offer form's "Offer Type" segmented control.
/// [discount]/[fixedPrice] carry a numeric value in
/// [Offer.discountValue] (percentage / AZN respectively); [gift] and
/// [buyOneGetOne] don't — their whole meaning is in the title/
/// description, there's no single number that represents "1+1" or a
/// free gift. [happyHour] also carries a [Offer.discountValue]
/// (percentage, same slider as [discount]) plus [Offer.activeHours]/
/// [Offer.activeDays] — it's a discount, just a time-boxed-within-the-
/// day one on top of the usual start/end date range. [firstVisit]
/// carries a [Offer.discountValue] like [discount] but no other
/// fields — its distinguishing behavior lives entirely in
/// `offers/{offerId}/redemptions/{uid}`, a single-use-per-user
/// activation tracked outside this entity (see `OfferRepository`'s
/// `watchIsRedeemedByMe`/`redeemOffer`).
///
/// [birthday] is NEVER a manual choice in the create form's segmented
/// control (see `_OfferTypeSelector` in `create_offer_screen.dart` —
/// it's simply not one of the options rendered there) — it only ever
/// gets set by the birthday-match deep-link flow, which pre-fills
/// [Offer.birthdayMatchId]/[Offer.targetUserIds] and reuses
/// [Offer.startDate]/[endDate] for the (non-editable, from that
/// screen) validity window rather than a second set of date fields.
enum OfferType { discount, gift, buyOneGetOne, fixedPrice, happyHour, firstVisit, birthday }

class OfferTypeConverter implements JsonConverter<OfferType, String?> {
  const OfferTypeConverter();

  @override
  OfferType fromJson(String? json) =>
      OfferType.values.firstWhere((t) => t.name == json, orElse: () => OfferType.discount);

  @override
  String toJson(OfferType type) => type.name;
}

/// The daily time-of-day window an [OfferType.happyHour] offer is
/// active — plain `HH:mm` strings (not [DateTime]/[TimeOfDay]) since
/// this is a recurring daily window, not a single instant; storing it
/// as a wall-clock string sidesteps timezone/date-math entirely, the
/// same reasoning as `OpeningHours`' `DayHours` in `venue.dart`.
class ActiveHours {
  final String start;
  final String end;

  const ActiveHours({required this.start, required this.end});

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  static ActiveHours? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final start = map['start'] as String?;
    final end = map['end'] as String?;
    if (start == null || end == null) return null;
    return ActiveHours(start: start, end: end);
  }
}

class ActiveHoursConverter implements JsonConverter<ActiveHours?, Map<String, dynamic>?> {
  const ActiveHoursConverter();

  @override
  ActiveHours? fromJson(Map<String, dynamic>? json) => ActiveHours.fromMap(json);

  @override
  Map<String, dynamic>? toJson(ActiveHours? hours) => hours?.toMap();
}

/// A time-boxed promotion published by a venue owner (Kəşf et →
/// Təkliflər). [category] deliberately reuses [VenueCategory] rather
/// than a second, near-duplicate enum — an offer's category is always
/// its venue's category, so a separate taxonomy would just be two
/// lists that can silently drift apart.
///
/// [venueName]/[venuePhotoUrl]/[address]/[lat]/[lng] are denormalized
/// from the venue at creation time (not live-joined) — the offer list
/// needs venue identity and position on every card/query, and
/// re-fetching each offer's venue doc on every read would turn one
/// list screen into an N+1 read pattern. [lat]/[lng] mirror
/// [Venue.lat]/[Venue.lng]'s own shape exactly: the GeoFlutterFire
/// `position` field (geopoint + geohash) is a write/query-layer detail
/// the repository/datasource own, never part of this entity — same
/// division of responsibility as `Venue`, and the same mistake (an
/// entity field the datasource stopped writing) is exactly what broke
/// venues just now, so this deliberately isn't repeated here.
@freezed
class Offer with _$Offer {
  const Offer._();

  const factory Offer({
    required String id,
    required String ownerId,
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    @VenueCategoryConverter() required VenueCategory category,
    required String title,
    required String description,
    @OfferTypeConverter() required OfferType offerType,

    /// Percentage (0-100) for [OfferType.discount], AZN amount for
    /// [OfferType.fixedPrice]. Null for [OfferType.gift]/
    /// [OfferType.buyOneGetOne].
    double? discountValue,
    required double lat,
    required double lng,
    required String address,

    /// Denormalized from the venue's own reverse-geocoded country —
    /// powers "Ölkə üzrə", the exact same radius mode Venues/İnsanlar
    /// already support. Null when the venue itself has no resolved
    /// country.
    String? country,
    @TimestampConverter() required DateTime startDate,
    @TimestampConverter() required DateTime endDate,
    String? imageUrl,

    /// Optional terms/eligibility text — free-form, shown as-is.
    String? terms,

    /// 'pending' | 'approved' | 'needs_revision' | 'rejected' — same
    /// moderation lifecycle as [Venue.status], including the
    /// firestore.rules restriction that only the admin panel's Server
    /// Actions may change it.
    @Default('pending') String status,

    /// Set by the reviewing admin/moderator when [status] is
    /// 'needs_revision' or 'rejected'. Null otherwise.
    String? reviewNote,

    /// Admin/moderator uid who last set [status]. Null until reviewed.
    String? reviewedBy,

    /// When [reviewedBy] last set [status]. Null until reviewed.
    @NullableTimestampConverter() DateTime? reviewedAt,

    /// The `payments/{paymentId}` doc backing this offer's listing fee
    /// — same payment/refund state machine as [Venue.paymentId]. Null
    /// on offers created before this field existed.
    String? paymentId,

    /// Only set while [status] is 'needs_revision' — same 7-day
    /// resubmit-or-auto-reject-and-refund contract as
    /// [Venue.revisionDeadline]. Grant-of-trust, see firestore.rules.
    @NullableTimestampConverter() DateTime? revisionDeadline,
    @TimestampConverter() required DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,

    /// Set by the owner via `OfferController.boostOffer` (Offer Details
    /// → the owner's own offer → the 3-dot menu, replacing the heart
    /// every other viewer sees there). While in the future, the offer
    /// sorts ahead of non-boosted ones in `nearbyOffersProvider` —
    /// unlike venues (governed purely by user likes/votes, see
    /// `Venue`'s own doc comments), a real time-boxed paid boost is the
    /// actual product decision for offers specifically.
    @NullableTimestampConverter() DateTime? boostedUntil,

    /// Only set for [OfferType.happyHour] — the daily window (e.g.
    /// 15:00–17:00) the discount is active. Null for every other type.
    @ActiveHoursConverter() ActiveHours? activeHours,

    /// Only meaningful for [OfferType.happyHour] — 'mon'..'sun' keys the
    /// window runs on. The create form defaults every day checked, so
    /// this is only ever empty for a type other than [happyHour].
    @Default(<String>[]) List<String> activeDays,

    /// Server-computed, never client-written (locked in firestore.rules
    /// same as [status]) — true for every offer type except
    /// [OfferType.happyHour], for which it tracks whether right now
    /// falls inside [activeHours]/[activeDays] (Azerbaijan local time).
    /// `maintainHappyHourActiveFlag`/`refreshHappyHourOfferStatus` in
    /// `functions/src/index.ts` are the only writers — a client-side
    /// device-clock check couldn't be trusted for this, since it'd let
    /// someone just set their phone's clock to see a discount outside
    /// its real window. Discovery queries filter on this field so an
    /// inactive Happy Hour offer simply doesn't appear; the owner's own
    /// "Təkliflərim" list ignores it and shows a status label instead.
    @Default(true) bool happyHourActive,

    /// Only set for [OfferType.birthday] — the `birthdayMatches/{id}`
    /// doc this offer was created from. Null for every other type.
    String? birthdayMatchId,

    /// Only meaningful for [OfferType.birthday] — the specific uids this
    /// offer is for, copied from the matching `birthdayMatches` doc
    /// at creation time (so it stays correct even if that doc is later
    /// pruned/changes). Empty for every other type. `nearbyOffersProvider`
    /// and every other "everyone" offer stream filters a [birthday]
    /// offer down to only viewers whose uid is in this list — see
    /// `OfferRepository`'s query doc comments.
    @Default(<String>[]) List<String> targetUserIds,

    /// Only meaningful for [OfferType.birthday] — the owner's optional
    /// note to the birthday user(s) (max 100 chars, enforced by the
    /// create form). Null when left blank.
    String? personalMessage,
  }) = _Offer;

  factory Offer.fromJson(Map<String, dynamic> json) => _$OfferFromJson(json);

  /// Convenience for the repository layer — mirrors
  /// `Venue.fromFirestore`.
  factory Offer.fromFirestore(String id, Map<String, dynamic> data) {
    return Offer.fromJson({...data, 'id': id});
  }

  bool get isExpired => DateTime.now().isAfter(endDate);

  bool get isBoosted => boostedUntil != null && DateTime.now().isBefore(boostedUntil!);

  bool isOwnedBy(String uid) => ownerId == uid;
}
