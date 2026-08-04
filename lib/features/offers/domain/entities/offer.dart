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
/// free gift.
enum OfferType { discount, gift, buyOneGetOne, fixedPrice }

class OfferTypeConverter implements JsonConverter<OfferType, String?> {
  const OfferTypeConverter();

  @override
  OfferType fromJson(String? json) =>
      OfferType.values.firstWhere((t) => t.name == json, orElse: () => OfferType.discount);

  @override
  String toJson(OfferType type) => type.name;
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

    /// Contact fields are entered fresh per offer (not pulled live from
    /// the venue profile, which has no phone/website of its own today)
    /// — each is only shown on the details screen when its paired
    /// `show*` toggle is on, matching the form's per-field visibility
    /// toggles.
    String? contactPhone,
    @Default(false) bool showContactPhone,
    String? contactWebsite,
    @Default(false) bool showContactWebsite,
    String? contactInstagram,
    @Default(false) bool showContactInstagram,

    /// Defaults to 'active' — no moderation queue exists yet, mirroring
    /// [Venue.status]'s exact same not-yet-used moderation readiness.
    @Default('active') String status,
    @TimestampConverter() required DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
  }) = _Offer;

  factory Offer.fromJson(Map<String, dynamic> json) => _$OfferFromJson(json);

  /// Convenience for the repository layer — mirrors
  /// `Venue.fromFirestore`.
  factory Offer.fromFirestore(String id, Map<String, dynamic> data) {
    return Offer.fromJson({...data, 'id': id});
  }

  bool get isExpired => DateTime.now().isAfter(endDate);

  bool isOwnedBy(String uid) => ownerId == uid;
}
