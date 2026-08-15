import 'dart:io';

import '../entities/post.dart';
import '../entities/post_comment.dart';

abstract class PostRepository {
  /// Uploads [file] to Storage (under [userId]'s own prefix, matching
  /// the owner-only write rule) and returns its download URL.
  /// [onProgress] receives a 0.0–1.0 fraction as the upload advances.
  Future<String> uploadMedia({
    required String userId,
    required File file,
    required PostMediaType type,
    required void Function(double progress) onProgress,
  });

  /// Creates the Firestore `posts/{id}` doc — [mediaUrl] (and
  /// [thumbnailUrl], for videos) must already be Storage download URLs
  /// (i.e. [uploadMedia] has completed for each).
  Future<void> createPost({
    required String userId,
    required String mediaUrl,
    required PostMediaType mediaType,
    String? thumbnailUrl,
    String caption,
  });

  Stream<List<Post>> watchUserPosts(String userId);

  Stream<Post?> watchPost(String postId);

  /// The only field a post can be edited after sharing.
  Future<void> updateCaption({required String postId, required String caption});

  /// Deletes the Firestore doc AND the Storage object(s) at [mediaUrl]
  /// (and [thumbnailUrl], if the post had one).
  Future<void> deletePost({required String postId, required String mediaUrl, String? thumbnailUrl});

  Stream<bool> watchIsLikedByMe(String postId, String uid);

  /// Creates/deletes `posts/{postId}/likes/{uid}` — the actual
  /// `likesCount` field updates server-side via a Firestore-triggered
  /// Cloud Function watching that subcollection, never written by the
  /// client directly.
  Future<void> toggleLike({required String postId, required String uid, required bool like});

  Stream<List<PostComment>> watchComments(String postId);

  /// Same "server updates the count" contract as [toggleLike] — this
  /// only writes the comment doc. [replyToCommentId] is null for a
  /// top-level comment, or the parent comment's id for a reply.
  Future<void> addComment({
    required String postId,
    required String uid,
    required String text,
    String? replyToCommentId,
  });

  /// The only field a comment can be edited after posting — author only.
  Future<void> updateComment({required String postId, required String commentId, required String text});

  /// Author of the comment OR the post's own owner may delete it (both
  /// checked server-side by firestore.rules, not here).
  Future<void> deleteComment({required String postId, required String commentId});

  Stream<bool> watchIsCommentLikedByMe(String postId, String commentId, String uid);

  /// Same "server updates the count" contract as [toggleLike].
  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required String uid,
    required bool like,
  });
}
