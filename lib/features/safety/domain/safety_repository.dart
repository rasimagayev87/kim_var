/// Abstraction over blocking and reporting other users.
abstract class SafetyRepository {
  Future<void> blockUser({required String myUid, required String blockedUid});

  Future<void> unblockUser({required String myUid, required String blockedUid});

  Stream<Set<String>> watchBlockedUserIds(String myUid);

  /// True if either [uidA] has blocked [uidB], or vice versa — the
  /// single shared implementation `FirebaseChatRepository` and
  /// `FirebaseCallRepository` both call before sending/starting
  /// anything, so the actual enforcement (`firestore.rules`, Düzəliş
  /// Prompt 5) and this pre-check never drift out of sync with each
  /// other's read/error-handling shape.
  Future<bool> isBlockedPair(String uidA, String uidB);

  Future<void> reportUser({
    required String reporterId,
    required String reportedId,
    required String reason,
    String? chatId,
  });
}
