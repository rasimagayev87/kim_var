enum ChatFailure {
  /// The sender already used their one opening message and the
  /// recipient hasn't accepted the request yet.
  requestPending,

  /// The recipient explicitly declined the request.
  requestDeclined,

  /// Either side has blocked the other.
  blocked,
}

class ChatException implements Exception {
  final ChatFailure type;
  const ChatException(this.type);
}
