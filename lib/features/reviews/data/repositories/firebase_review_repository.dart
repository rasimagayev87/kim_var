import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

class FirebaseReviewRepository implements ReviewRepository {
  FirebaseReviewRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reviews => _firestore.collection('reviews');

  String _reviewId(String venueId, String userId) => '${venueId}_$userId';

  @override
  Stream<List<Review>> watchVenueReviews(String venueId) {
    return _reviews
        .where('venueId', isEqualTo: venueId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList());
  }

  @override
  Stream<Review?> watchMyReview({required String venueId, required String userId}) {
    return _reviews.doc(_reviewId(venueId, userId)).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return Review.fromFirestore(snap.id, data);
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
