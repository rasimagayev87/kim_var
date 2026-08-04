import '../safety_repository.dart';

class ReportUserUseCase {
  const ReportUserUseCase(this._repository);

  final SafetyRepository _repository;

  Future<void> call({
    required String reporterId,
    required String reportedId,
    required String reason,
    String? chatId,
  }) {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty || reporterId == reportedId) return Future.value();
    return _repository.reportUser(
      reporterId: reporterId,
      reportedId: reportedId,
      reason: trimmedReason,
      chatId: chatId,
    );
  }
}
