import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/venue_follow_repository.dart';

class FirebaseVenueFollowRepository implements VenueFollowRepository {
  FirebaseVenueFollowRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _followers(String venueId) =>
      _firestore.collection('venues').doc(venueId).collection('followers');

  @override
  Stream<bool> watchIsFollowing({
    required String venueId,
    required String uid,
  }) {
    return _followers(venueId).doc(uid).snapshots().map((doc) => doc.exists);
  }

  @override
  Stream<List<String>> watchFollowedVenueIds(String uid) {
    // collectionGroup so this works across every venue's `followers`
    // subcollection at once — `userId` is denormalized onto each doc
    // (redundant with the doc's own id) specifically so this query has
    // something to filter on; the venue id itself comes from the
    // matched doc's own parent path, not a stored field.
    return _firestore
        .collectionGroup('followers')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => d.reference.parent.parent!.id).toList(),
        );
  }

  @override
  Future<void> follow({required String venueId, required String uid}) {
    return _followers(
      venueId,
    ).doc(uid).set({'userId': uid, 'followedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> unfollow({required String venueId, required String uid}) {
    return _followers(venueId).doc(uid).delete();
  }
}
