enum ChatFailure {
  /// The sender already used their one opening message and the
  /// recipient hasn't accepted the request yet.
  requestPending,

  /// The recipient explicitly declined the request.
  requestDeclined,

  /// Either side has blocked the other.
  blocked,

  /// The recipient's "Kim mənə mesaj göndərə bilər" setting doesn't
  /// allow this sender to start a new chat with them (only checked
  /// when no chat exists yet — an already-accepted conversation is
  /// never retroactively blocked by a later setting change).
  notAllowedByRecipient,
}

class ChatException implements Exception {
  final ChatFailure type;
  const ChatException(this.type);
}
