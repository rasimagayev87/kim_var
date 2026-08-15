import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import '../../../../core/utils/app_logger.dart';
import '../../data/repositories/firebase_post_repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_comment.dart';
import '../../domain/repositories/post_repository.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) => FirebasePostRepository());

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final userPostsProvider = StreamProvider.autoDispose.family<List<Post>, String>((ref, userId) {
  return ref.watch(postRepositoryProvider).watchUserPosts(userId);
});

/// Sum of `likesCount` across every post [userId] has shared — the real,
/// media-based number the Təqib/Təqibçi/Bəyənmə stats row shows for
/// "Bəyənmə" (see `ProfileTab`/`UserProfileScreen`). Swiping/cards no
/// longer exist, so this replaces the old swipe-based `heartCount`.
final userTotalPostLikesProvider = Provider.autoDispose.family<int, String>((ref, userId) {
  final posts = ref.watch(userPostsProvider(userId)).valueOrNull ?? const [];
  return posts.fold<int>(0, (sum, p) => sum + p.likesCount);
});

final isPostLikedByMeProvider = StreamProvider.autoDispose.family<bool, String>((ref, postId) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(false);
  return ref.watch(postRepositoryProvider).watchIsLikedByMe(postId, uid);
});

final postCommentsProvider = StreamProvider.autoDispose.family<List<PostComment>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchComments(postId);
});

final postByIdProvider = StreamProvider.autoDispose.family<Post?, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
});

/// Keyed by a (postId, commentId) record — Riverpod families accept
/// records as a single family argument.
final isCommentLikedByMeProvider = StreamProvider.autoDispose.family<bool, (String postId, String commentId)>((ref, key) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(false);
  return ref.watch(postRepositoryProvider).watchIsCommentLikedByMe(key.$1, key.$2, uid);
});

class PostController {
  PostController(this._ref);

  final Ref _ref;

  /// Uploads [file] then creates the Firestore post doc. Returns true
  /// on success (logged internally on failure); [onProgress] mirrors
  /// the upload task's 0.0–1.0 fraction.
  Future<bool> uploadAndCreatePost({
    required File file,
    required PostMediaType mediaType,
    required String caption,
    required void Function(double progress) onProgress,
  }) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      final repo = _ref.read(postRepositoryProvider);
      final mediaUrl = await repo.uploadMedia(userId: uid, file: file, type: mediaType, onProgress: onProgress);
      final thumbnailUrl = mediaType == PostMediaType.video
          ? await _uploadVideoThumbnail(repo: repo, uid: uid, videoFile: file)
          : null;
      await repo.createPost(userId: uid, mediaUrl: mediaUrl, mediaType: mediaType, thumbnailUrl: thumbnailUrl, caption: caption);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.uploadAndCreatePost', e, st);
      return false;
    }
  }

  /// Extracts the video's first frame as a JPEG and uploads it through
  /// the same [PostRepository.uploadMedia] path used for photo posts —
  /// best-effort: a failure here just means the post is created without
  /// a [Post.thumbnailUrl] (grid views fall back to their existing
  /// placeholder), not a failed share.
  Future<String?> _uploadVideoThumbnail({
    required PostRepository repo,
    required String uid,
    required File videoFile,
  }) async {
    try {
      final path = await vt.VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        imageFormat: vt.ImageFormat.JPEG,
        quality: 75,
      );
      if (path == null) return null;
      return await repo.uploadMedia(userId: uid, file: File(path), type: PostMediaType.photo, onProgress: (_) {});
    } catch (e, st) {
      logError('post_providers.PostController._uploadVideoThumbnail', e, st);
      return null;
    }
  }

  Future<bool> updateCaption(String postId, String caption) async {
    try {
      await _ref.read(postRepositoryProvider).updateCaption(postId: postId, caption: caption);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.updateCaption', e, st);
      return false;
    }
  }

  Future<bool> deletePost(String postId, String mediaUrl, {String? thumbnailUrl}) async {
    try {
      await _ref.read(postRepositoryProvider).deletePost(postId: postId, mediaUrl: mediaUrl, thumbnailUrl: thumbnailUrl);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.deletePost', e, st);
      return false;
    }
  }

  Future<bool> toggleLike(String postId, bool like) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(postRepositoryProvider).toggleLike(postId: postId, uid: uid, like: like);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.toggleLike', e, st);
      return false;
    }
  }

  Future<bool> addComment(String postId, String text, {String? replyToCommentId}) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref
          .read(postRepositoryProvider)
          .addComment(postId: postId, uid: uid, text: text, replyToCommentId: replyToCommentId);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.addComment', e, st);
      return false;
    }
  }

  Future<bool> updateComment(String postId, String commentId, String text) async {
    try {
      await _ref.read(postRepositoryProvider).updateComment(postId: postId, commentId: commentId, text: text);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.updateComment', e, st);
      return false;
    }
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      await _ref.read(postRepositoryProvider).deleteComment(postId: postId, commentId: commentId);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.deleteComment', e, st);
      return false;
    }
  }

  Future<bool> toggleCommentLike(String postId, String commentId, bool like) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(postRepositoryProvider).toggleCommentLike(postId: postId, commentId: commentId, uid: uid, like: like);
      return true;
    } catch (e, st) {
      logError('post_providers.PostController.toggleCommentLike', e, st);
      return false;
    }
  }
}

final postControllerProvider = Provider<PostController>((ref) => PostController(ref));
