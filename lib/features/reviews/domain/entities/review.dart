import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../venues/domain/entities/venue.dart' show TimestampConverter;

part 'review.freezed.dart';
part 'review.g.dart';

/// The venue owner's one and only public reply to a [Review] — see
/// `firestore.rules`' `reviews/{reviewId}` owner-update branch, which
/// only permits setting this once (`resource.data.ownerReply == null`).
@freezed
class ReviewOwnerReply with _$ReviewOwnerReply {
  const factory ReviewOwnerReply({required String text, @TimestampConverter() required DateTime repliedAt}) =
      _ReviewOwnerReply;

  factory ReviewOwnerReply.fromJson(Map<String, dynamic> json) => _$ReviewOwnerReplyFromJson(json);
}

/// `reviews/{venueId}_{userId}` — the composite id (same convention as
/// `follows/{viewerId}_{ownerId}`) is what makes "one review per user
/// per venue" structural rather than something a rule has to search
/// for: a second review attempt just overwrites the first doc instead
/// of creating a sibling. [waitlistEntryId] is the proof of a real,
/// staff-confirmed visit this review is built on — `firestore.rules`
/// `get()`s that waitlist entry and requires `status == seated` and
/// matching `userId` before allowing a write here, so this can't be
/// faked by a raw client write either.
@freezed
class Review with _$Review {
  const Review._();

  const factory Review({
    required String id,
    required String venueId,
    required String userId,
    required int rating,
    required String comment,
    required String waitlistEntryId,
    ReviewOwnerReply? ownerReply,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime updatedAt,
  }) = _Review;

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);

  factory Review.fromFirestore(String id, Map<String, dynamic> data) => Review.fromJson({...data, 'id': id});
}
