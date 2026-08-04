class PostComment {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final int likesCount;

  /// Null for a top-level comment; the parent comment's [id] for a
  /// reply. Replies live in the same flat `comments` subcollection —
  /// the UI groups them under their parent rather than nesting a
  /// second subcollection level.
  final String? replyToCommentId;

  const PostComment({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.likesCount = 0,
    this.replyToCommentId,
  });
}
