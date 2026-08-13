import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/follow_repository.dart';

class FirebaseFollowRepository implements FollowRepository {
  FirebaseFollowRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _follows => _firestore.collection('follows');

  /// Directional (not a sorted pair id) — following isn't mutual, so A
  /// following B and B following A are two independent docs.
  String _docId(String followerId, String followeeId) => '${followerId}_$followeeId';

  @override
  Stream<int> watchFollowersCount(String uid) {
    return _follows.where('followeeId', isEqualTo: uid).snapshots().map((snap) => snap.docs.length);
  }

  @override
  Stream<int> watchFollowingCount(String uid) {
    return _follows.where('followerId', isEqualTo: uid).snapshots().map((snap) => snap.docs.length);
  }

  @override
  Stream<bool> watchIsFollowing({required String followerId, required String followeeId}) {
    return _follows.doc(_docId(followerId, followeeId)).snapshots().map((doc) => doc.exists);
  }

  @override
  Future<bool> isFollowingOrFollowedBy(String uidA, String uidB) async {
    final results = await Future.wait([
      _follows.doc(_docId(uidA, uidB)).get(),
      _follows.doc(_docId(uidB, uidA)).get(),
    ]);
    return results[0].exists || results[1].exists;
  }

  @override
  Future<void> follow({required String followerId, required String followeeId}) {
    return _follows.doc(_docId(followerId, followeeId)).set({
      'followerId': followerId,
      'followeeId': followeeId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unfollow({required String followerId, required String followeeId}) {
    return _follows.doc(_docId(followerId, followeeId)).delete();
  }
}
