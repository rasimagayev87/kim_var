import 'dart:io';

import '../repositories/chat_repository.dart';

class SendAudioMessageUseCase {
  const SendAudioMessageUseCase(this._repository);

  final ChatRepository _repository;

  /// Matches the 10MB limit enforced by the chat-audio Storage rule —
  /// generous for a voice message recorded at the client's max duration.
  static const maxFileSizeBytes = 10 * 1024 * 1024;

  /// Voice messages are capped client-side at 5 minutes so a recording
  /// can't run away in the background and produce an oversized upload.
  static const maxDuration = Duration(minutes: 5);

  Future<void> call({
    required List<String> participantIds,
    required String senderId,
    required File audioFile,
    required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final sizeBytes = await audioFile.length();
    if (sizeBytes == 0 || sizeBytes > maxFileSizeBytes) {
      throw ArgumentError('Voice message must be non-empty and under 10MB.');
    }
    if (durationMs <= 0) {
      throw ArgumentError('Voice message must have a positive duration.');
    }
    return _repository.sendAudioMessage(
      participantIds: participantIds,
      senderId: senderId,
      audioFile: audioFile,
      durationMs: durationMs,
      onProgress: onProgress,
    );
  }
}
