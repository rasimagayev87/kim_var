import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/safety_repository.dart';

import '../../../../core/utils/app_logger.dart';

/// Backed by the `blockedUsers` array field already provisioned on
/// every `users/{uid}` document at onboarding (see
/// `FirebaseAuthRepository.completeOnboarding`), rather than a separate
/// collection — keeps a user's block list a single read/write.
class FirebaseSafetyRepository implements SafetyRepository {
  FirebaseSafetyRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<void> blockUser({required String myUid, required String blockedUid}) {
    return _users.doc(myUid).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUid]),
    });
  }

  @override
  Future<void> unblockUser({
    required String myUid,
    required String blockedUid,
  }) {
    return _users.doc(myUid).update({
      'blockedUsers': FieldValue.arrayRemove([blockedUid]),
    });
  }

  /// Reads both parties' own `users/{uid}.blockedUsers` directly.
  /// Düzəliş Prompt 5: once `firestore.rules`' `users/{userId}` `allow
  /// get` itself denies reading a blocked party's profile, THIS read
  /// throws `permission-denied` exactly when a block exists — so that
  /// specific code is treated as "yes, blocked" rather than propagated
  /// as an error. Any OTHER Firestore error (offline, `unavailable`,
  /// `deadline-exceeded`, ...) is rethrown — mapping every transient
  /// failure to "blocked" would show a wrong, alarming message to
  /// someone with a bad connection who was never blocked by anyone.
  @override
  Future<bool> isBlockedPair(String uidA, String uidB) async {
    try {
      final results = await Future.wait([
        _users.doc(uidA).get(),
        _users.doc(uidB).get(),
      ]);
      final aBlocked =
          (results[0].data()?['blockedUsers'] as List?)?.cast<String>() ??
          const [];
      final bBlocked =
          (results[1].data()?['blockedUsers'] as List?)?.cast<String>() ??
          const [];
      return aBlocked.contains(uidB) || bBlocked.contains(uidA);
    } on FirebaseException catch (e) {
      if (errorCodeIs(e.code, 'permission-denied')) return true;
      rethrow;
    }
  }

  @override
  Stream<Set<String>> watchBlockedUserIds(String myUid) {
    return _users
        .doc(myUid)
        .snapshots()
        .map(
          (doc) =>
              (doc.data()?['blockedUsers'] as List?)?.cast<String>().toSet() ??
              const {},
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
    batch.update(_users.doc(reportedId), {
      'reportedCount': FieldValue.increment(1),
    });
    await batch.commit();
  }
}
