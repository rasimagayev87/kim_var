import 'dart:io';

import '../repositories/chat_repository.dart';

class SendImageMessageUseCase {
  const SendImageMessageUseCase(this._repository);

  final ChatRepository _repository;

  /// Matches the 5MB limit enforced by the chat-photo Storage rule.
  static const maxFileSizeBytes = 5 * 1024 * 1024;

  Future<void> call({
    required List<String> participantIds,
    required String senderId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final sizeBytes = await imageFile.length();
    if (sizeBytes == 0 || sizeBytes > maxFileSizeBytes) {
      throw ArgumentError('Image must be non-empty and under 5MB.');
    }
    return _repository.sendImageMessage(
      participantIds: participantIds,
      senderId: senderId,
      imageFile: imageFile,
      onProgress: onProgress,
    );
  }
}
