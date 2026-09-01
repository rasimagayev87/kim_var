import '../entities/review.dart';

abstract class ReviewRepository {
  /// P0 / M-7 — backed by the `listVenueReviews` callable, not a live
  /// Firestore query (`reviews` no longer permits `list`). Emits once.
  Stream<List<Review>> watchVenueReviews(String venueId);

  /// One-shot variant of [watchVenueReviews], for callers that want to
  /// refresh explicitly after writing a review.
  Future<List<Review>> fetchVenueReviews(String venueId);

  Stream<Review?> watchMyReview({
    required String venueId,
    required String userId,
  });

  /// Creates or updates `reviews/{venueId}_{userId}` — the same call
  /// either way, `set()` overwrites whatever was there. [waitlistEntryId]
  /// must belong to [userId] and have `status: seated`, or
  /// `firestore.rules` rejects the write.
  Future<void> submitReview({
    required String venueId,
    required String userId,
    required int rating,
    required String comment,
    required String waitlistEntryId,
  });

  /// The venue owner's one-time public reply — `firestore.rules` only
  /// allows this while [Review.ownerReply] is still null.
  Future<void> submitOwnerReply({
    required String reviewId,
    required String text,
  });

  Future<void> reportReview({
    required String reviewId,
    required String venueId,
    required String reporterId,
    required String reason,
  });
}
