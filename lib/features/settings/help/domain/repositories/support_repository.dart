import '../entities/support_message.dart';

abstract class SupportRepository {
  Future<void> sendMessage({
    required String uid,
    required SupportMessageType type,
    required String message,
  });
}
