import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../venues/domain/entities/venue.dart'
    show VenueCategory, VenueCategoryConverter, TimestampConverter, NullableTimestampConverter;

part 'pinbox.freezed.dart';
part 'pinbox.g.dart';

/// A surprise-box discount listing (Kəşf et → Fürsətlər → PinBox) — a
/// venue owner bundles unsold/soon-to-expire stock into a fixed-price
/// box, buyers reserve one via [PinBoxOrder] and pick it up in person
/// within [pickupWindowStart]/[pickupWindowEnd]. Only ever created for
/// [kPinboxEligibleVenueCategories] venues (see venue.dart) — a fixed
/// product rule, not admin-configurable.
///
/// [venueName]/[venuePhotoUrl]/[category]/[lat]/[lng]/[address]/[country]
/// are denormalized from the venue at creation time — same reasoning
/// (and same shape) as [Offer]'s own denormalized venue fields.
///
/// Unlike [Offer]/[Venue], there is no `paymentId`/`revisionDeadline` —
/// PinBox has no flat listing fee; PeakPin's revenue is the per-order
/// commission reconciled monthly (see the (not-yet-modeled-in-Flutter)
/// `venuePayouts` collection, Cloud-Function/admin-panel only).
@freezed
class PinBox with _$PinBox {
  const PinBox._();

  const factory PinBox({
    required String id,
    required String ownerId,
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    @VenueCategoryConverter() required VenueCategory category,
    required String title,
    required String description,
    String? imageUrl,
    required double lat,
    required double lng,
    required String address,
    String? country,

    /// Menu/original value of the box's contents — struck through next
    /// to [pinboxPrice] on every card, same visual convention as the
    /// reference mockups.
    required double originalPrice,

    /// What the buyer actually pays — [discountPercent] is always
    /// derived from these two, never stored separately, so the two
    /// numbers can't silently drift.
    required double pinboxPrice,
    required int stockTotal,

    /// Client-visible cache of remaining stock — the SOURCE of truth is
    /// server-side (a Cloud Function transaction decrements this
    /// atomically on each successful order, see PinBox Faza 7's doc
    /// comment on why the non-transactional `availableSeats` pattern
    /// was deliberately NOT reused here). Locked from direct client
    /// writes in firestore.rules.
    required int stockRemaining,
    @TimestampConverter() required DateTime pickupWindowStart,
    @TimestampConverter() required DateTime pickupWindowEnd,

    /// 'pending' | 'active' | 'soldOut' | 'expired' | 'rejected' |
    /// 'needs_revision' — same moderation lifecycle shape as
    /// [Offer.status]/[Venue.status]; only the admin panel's Server
    /// Actions may move it off 'pending'. Unlike Offer/Venue there's no
    /// `revisionDeadline` field — a PinBox listing has no upfront fee
    /// to protect with an auto-reject/refund clock, so 'needs_revision'
    /// just waits on the owner's own resubmission via `resubmitPinBox`.
    @Default('pending') String status,
    String? reviewNote,
    String? reviewedBy,
    @NullableTimestampConverter() DateTime? reviewedAt,
    @TimestampConverter() required DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
  }) = _PinBox;

  factory PinBox.fromJson(Map<String, dynamic> json) => _$PinBoxFromJson(json);

  /// Convenience for the repository layer — mirrors `Offer.fromFirestore`.
  factory PinBox.fromFirestore(String id, Map<String, dynamic> data) {
    return PinBox.fromJson({...data, 'id': id});
  }

  int get discountPercent {
    if (originalPrice <= 0) return 0;
    return (((originalPrice - pinboxPrice) / originalPrice) * 100).round();
  }

  bool get isSoldOut => stockRemaining <= 0;

  bool isOwnedBy(String uid) => ownerId == uid;
}
