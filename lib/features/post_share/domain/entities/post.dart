enum PostMediaType { photo, video }

/// A profile feed post — see firestore.rules' `posts/{postId}` block.
/// `likesCount`/`commentsCount` are server-computed only (Cloud
/// Functions triggers on the `likes`/`comments` subcollections); never
/// written directly by the client.
class Post {
  final String id;
  final String userId;
  final String mediaUrl;
  final PostMediaType mediaType;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final DateTime? createdAt;

  const Post({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.createdAt,
  });
}
