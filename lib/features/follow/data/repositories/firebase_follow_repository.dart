import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/follow_repository.dart';

class FirebaseFollowRepository implements FollowRepository {
  FirebaseFollowRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _follows => _firestore.collection('follows');

  /// Directional (not a sorted pair id) — following isn't mutual, so A
  /// following B and B following A are two independent docs.
  String _docId(String followerId, String followeeId) => '${followerId}_$followeeId';

  /// A doc with no `status` field predates "Hesab gizliliyi" — every
  /// edge created back then was a real, instant, accepted follow, so
  /// absence reads as accepted rather than pending. Only an explicit
  /// `'pending'` value means "not yet accepted".
  bool _isAccepted(Map<String, dynamic>? data) => data != null && data['status'] != 'pending';
  bool _isPendingData(Map<String, dynamic>? data) => data != null && data['status'] == 'pending';

  @override
  Stream<int> watchFollowersCount(String uid) {
    return _follows
        .where('followeeId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.where((d) => _isAccepted(d.data())).length);
  }

  @override
  Stream<int> watchFollowingCount(String uid) {
    return _follows
        .where('followerId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.where((d) => _isAccepted(d.data())).length);
  }

  @override
  Stream<bool> watchIsFollowing({required String followerId, required String followeeId}) {
    return _follows.doc(_docId(followerId, followeeId)).snapshots().map((doc) => doc.exists && _isAccepted(doc.data()));
  }

  @override
  Stream<bool> watchIsPending({required String followerId, required String followeeId}) {
    return _follows
        .doc(_docId(followerId, followeeId))
        .snapshots()
        .map((doc) => doc.exists && _isPendingData(doc.data()));
  }

  @override
  Future<bool> isAcceptedFollowerOf({required String viewerId, required String ownerId}) async {
    final doc = await _follows.doc(_docId(viewerId, ownerId)).get();
    return doc.exists && _isAccepted(doc.data());
  }

  @override
  Future<void> follow({required String followerId, required String followeeId, required bool requiresApproval}) {
    return _follows.doc(_docId(followerId, followeeId)).set({
      'followerId': followerId,
      'followeeId': followeeId,
      'status': requiresApproval ? 'pending' : 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unfollow({required String followerId, required String followeeId}) {
    return _follows.doc(_docId(followerId, followeeId)).delete();
  }

  @override
  Future<void> acceptFollowRequest({required String followerId, required String followeeId}) {
    return _follows.doc(_docId(followerId, followeeId)).update({'status': 'accepted'});
  }

  @override
  Future<void> declineFollowRequest({required String followerId, required String followeeId}) {
    return _follows.doc(_docId(followerId, followeeId)).delete();
  }
}
