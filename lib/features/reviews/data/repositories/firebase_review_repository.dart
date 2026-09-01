import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

import '../../../../core/utils/callables.dart';

class FirebaseReviewRepository implements ReviewRepository {
  FirebaseReviewRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reviews => _firestore.collection('reviews');

  String _reviewId(String venueId, String userId) => '${venueId}_$userId';

  /// See `FirebaseVenueRepository._safeVenue`'s doc comment — same
  /// per-document isolation, applied here for `Review`.
  Review? _safeReview(String id, Map<String, dynamic> data) {
    try {
      return Review.fromFirestore(id, data);
    } catch (e, st) {
      logError('firebase_review_repository.Review.fromFirestore($id)', e, st);
      return null;
    }
  }

  /// P0 / M-7 — server-side, was a raw `reviews` LIST query.
  ///
  /// A review can only exist behind `hasVerifiedVisit`, so it proves the
  /// author was physically inside the venue; with `{venueId}_{userId}`
  /// document ids, an open `list` handed any signed-in account the whole
  /// "who was where" graph. `firestore.rules` now denies `list`
  /// outright. The callable additionally filters blocked pairs in both
  /// directions, which this query never did.
  ///
  /// No longer a live `snapshots()` stream — a deliberate, accepted
  /// trade. Callers that write a review invalidate this provider to
  /// refresh (see `review_providers.dart`); `watchMyReview` below is
  /// untouched and still real-time, since a single-document `.doc()`
  /// read is a `get`, not a `list`.
  @override
  Stream<List<Review>> watchVenueReviews(String venueId) {
    return Stream.fromFuture(fetchVenueReviews(venueId));
  }

  @override
  Future<List<Review>> fetchVenueReviews(String venueId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('listVenueReviews', options: callableOptions());
      final result = await callable.call<Map<String, dynamic>>({'venueId': venueId});
      final raw = (result.data['reviews'] as List).cast<dynamic>();
      return raw
          .map((e) => _safeReviewFromMap(Map<String, dynamic>.from(e as Map)))
          .whereType<Review>()
          .toList();
    } catch (e, st) {
      logError('firebase_review_repository.fetchVenueReviews', e, st);
      return const [];
    }
  }

  /// Same per-document isolation as [_safeReview], for the callable's
  /// plain-map response: one malformed entry drops out of the list
  /// instead of blanking the whole venue's reviews.
  Review? _safeReviewFromMap(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    try {
      return Review.fromJson(data);
    } catch (e, st) {
      logError('firebase_review_repository.Review.fromJson($id)', e, st);
      return null;
    }
  }

  @override
  Stream<Review?> watchMyReview({required String venueId, required String userId}) {
    return _reviews.doc(_reviewId(venueId, userId)).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return _safeReview(snap.id, data);
    });
  }

  @override
  Future<void> submitReview({
    required String venueId,
    required String userId,
    required int rating,
    required String comment,
    required String waitlistEntryId,
  }) {
    final ref = _reviews.doc(_reviewId(venueId, userId));
    // A transaction (not a plain `set`) so `createdAt` is stamped once
    // on the first write and never touched again on a later edit —
    // `merge: true` alone can't tell "first write" from "edit" the
    // way a read-then-write inside a transaction can.
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = <String, dynamic>{
        'venueId': venueId,
        'userId': userId,
        'rating': rating,
        'comment': comment,
        'waitlistEntryId': waitlistEntryId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snap.exists) data['createdAt'] = FieldValue.serverTimestamp();
      tx.set(ref, data, SetOptions(merge: true));
    });
  }

  @override
  Future<void> submitOwnerReply({required String reviewId, required String text}) {
    return _reviews.doc(reviewId).update({
      'ownerReply': {'text': text, 'repliedAt': FieldValue.serverTimestamp()},
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reportReview({
    required String reviewId,
    required String venueId,
    required String reporterId,
    required String reason,
  }) {
    return _firestore.collection('reviewReports').add({
      'reviewId': reviewId,
      'venueId': venueId,
      'reporterId': reporterId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
