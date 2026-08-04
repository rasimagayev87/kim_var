/// Abstraction over blocking and reporting other users.
abstract class SafetyRepository {
  Future<void> blockUser({required String myUid, required String blockedUid});

  Future<void> unblockUser({required String myUid, required String blockedUid});

  Stream<Set<String>> watchBlockedUserIds(String myUid);

  Future<void> reportUser({
    required String reporterId,
    required String reportedId,
    required String reason,
    String? chatId,
  });
}
