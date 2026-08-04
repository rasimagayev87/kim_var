import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/safety_repository.dart';

/// Backed by the `blockedUsers` array field already provisioned on
/// every `users/{uid}` document at onboarding (see
/// `FirebaseAuthRepository.completeOnboarding`), rather than a separate
/// collection — keeps a user's block list a single read/write.
class FirebaseSafetyRepository implements SafetyRepository {
  FirebaseSafetyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  @override
  Future<void> blockUser({required String myUid, required String blockedUid}) {
    return _users.doc(myUid).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUid]),
    });
  }

  @override
  Future<void> unblockUser({required String myUid, required String blockedUid}) {
    return _users.doc(myUid).update({
      'blockedUsers': FieldValue.arrayRemove([blockedUid]),
    });
  }

  @override
  Stream<Set<String>> watchBlockedUserIds(String myUid) {
    return _users.doc(myUid).snapshots().map(
          (doc) => (doc.data()?['blockedUsers'] as List?)?.cast<String>().toSet() ?? const {},
        );
  }

  @override
  Future<void> reportUser({
    required String reporterId,
    required String reportedId,
    required String reason,
    String? chatId,
  }) async {
    final batch = _firestore.batch();
    batch.set(_firestore.collection('reports').doc(), {
      'reporterId': reporterId,
      'reportedUserId': reportedId,
      'reason': reason,
      if (chatId != null) 'chatId': chatId,
      'timestamp': FieldValue.serverTimestamp(),
      // Moderation workflow state — flipped to 'reviewed'/'actioned'/
      // 'dismissed' by moderators outside the app (reports are
      // write-only from the client, see firestore.rules).
      'status': 'pending',
    });
    batch.update(_users.doc(reportedId), {'reportedCount': FieldValue.increment(1)});
    await batch.commit();
  }
}
