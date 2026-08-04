import '../repositories/chat_repository.dart';

/// Trims and validates the text before it ever reaches the repository —
/// the request-pending/declined/blocked rules themselves are enforced
/// by [ChatRepository.sendTextMessage].
class SendTextMessageUseCase {
  const SendTextMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call({
    required List<String> participantIds,
    required String senderId,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value();
    return _repository.sendTextMessage(
      participantIds: participantIds,
      senderId: senderId,
      text: trimmed,
    );
  }
}
