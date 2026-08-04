enum PostMediaType { photo, video }

class Post {
  final String id;
  final String userId;
  final String mediaUrl;
  final PostMediaType mediaType;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;

  /// A static JPEG cover frame for video posts — generated client-side
  /// at upload time (see [PostRepository.createPost]) so grid/list
  /// views can show the video's actual first frame with a plain
  /// `Image.network`, without decoding video per tile. Null for photo
  /// posts (mediaUrl is already an image) and for videos shared before
  /// this field existed.
  final String? thumbnailUrl;

  /// Optional caption written on the preview screen — the only field
  /// a post can be edited after sharing (see [PostRepository.updateCaption]).
  final String caption;

  const Post({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.thumbnailUrl,
    this.caption = '',
  });
}
