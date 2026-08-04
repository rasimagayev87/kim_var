import 'dart:io';

import '../repositories/chat_repository.dart';

class SendVideoMessageUseCase {
  const SendVideoMessageUseCase(this._repository);

  final ChatRepository _repository;

  /// Matches the 50MB limit enforced by the chat-video Storage rule.
  static const maxFileSizeBytes = 50 * 1024 * 1024;

  Future<void> call({
    required List<String> participantIds,
    required String senderId,
    required File videoFile,
    int? durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final sizeBytes = await videoFile.length();
    if (sizeBytes == 0 || sizeBytes > maxFileSizeBytes) {
      throw ArgumentError('Video must be non-empty and under 50MB.');
    }
    return _repository.sendVideoMessage(
      participantIds: participantIds,
      senderId: senderId,
      videoFile: videoFile,
      durationMs: durationMs,
      onProgress: onProgress,
    );
  }
}
