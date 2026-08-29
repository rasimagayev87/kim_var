import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/utils/exif_stripper.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_comment.dart';
import '../../domain/repositories/post_repository.dart';

class FirebasePostRepository implements PostRepository {
  FirebasePostRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<String> uploadMedia({
    required String userId,
    required File file,
    required PostMediaType type,
    required void Function(double progress) onProgress,
  }) async {
    final extension = type == PostMediaType.video ? 'mp4' : 'jpg';
    final contentType = type == PostMediaType.video
        ? 'video/mp4'
        : 'image/jpeg';
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';

    final storageRef = _storage.ref('posts/$userId/$fileName');
    // GPS EXIF strip (Düzəliş Prompt 3 / C#43) — image posts only;
    // `stripExifIfImage` fails open to the original file on a
    // non-image decode anyway, but skipping the attempt for video
    // avoids decoding a large file pointlessly.
    final uploadFile = type == PostMediaType.video ? file : await stripExifIfImage(file);
    final task = storageRef.putFile(
      uploadFile,
      SettableMetadata(contentType: contentType),
    );

    task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    await task;
    return storageRef.getDownloadURL();
  }

  @override
  Future<void> createPost({
    required String userId,
    required String mediaUrl,
    required PostMediaType mediaType,
    String? thumbnailUrl,
    String caption = '',
  }) {
    return _posts.add({
      'userId': userId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'commentsCount': 0,
    });
  }

  @override
  Stream<List<Post>> watchUserPosts(String userId, {required bool isOwnProfile}) {
    Query<Map<String, dynamic>> query = _posts.where('userId', isEqualTo: userId);
    if (!isOwnProfile) {
      query = query.where('authorIsPublic', isEqualTo: true);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  @override
  Stream<List<Post>> watchPublicVideoFeed({required int limit}) {
    return _publicVideoQuery().limit(limit).snapshots().map(
          (snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<List<Post>> fetchMorePublicVideos({
    required DateTime startAfter,
    required int limit,
  }) async {
    final snap = await _publicVideoQuery()
        .startAfter([Timestamp.fromDate(startAfter)])
        .limit(limit)
        .get();
    return snap.docs.map((d) => _fromDoc(d.id, d.data())).toList();
  }

  Query<Map<String, dynamic>> _publicVideoQuery() {
    return _posts
        .where('authorIsPublic', isEqualTo: true)
        .where('mediaType', isEqualTo: PostMediaType.video.name)
        .orderBy('createdAt', descending: true);
  }

  @override
  Stream<List<Post>> watchLikedPosts(String uid) =>
      _watchMirroredPosts(uid, 'likedPosts');

  @override
  Stream<List<Post>> watchRepostedPosts(String uid) =>
      _watchMirroredPosts(uid, 'reposts');

  /// Backs [watchLikedPosts]/[watchRepostedPosts] — both read a small
  /// `users/{uid}/{subcollection}` mirror (see [toggleLike]/[toggleRepost])
  /// ordered newest-first, then resolve each entry's id to the actual
  /// `posts/{id}` doc. A post deleted since being liked/reposted just
  /// silently drops out of the list rather than erroring.
  Stream<List<Post>> _watchMirroredPosts(String uid, String subcollection) {
    return _users
        .doc(uid)
        .collection(subcollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final postDocs = await Future.wait(
            snap.docs.map((d) => _posts.doc(d.id).get()),
          );
          return postDocs
              .where((d) => d.exists)
              .map((d) => _fromDoc(d.id, d.data()!))
              .toList();
        });
  }

  @override
  Stream<Post?> watchPost(String postId) {
    return _posts.doc(postId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return _fromDoc(snap.id, data);
    });
  }

  @override
  Future<void> updateCaption({
    required String postId,
    required String caption,
  }) {
    return _posts.doc(postId).update({'caption': caption});
  }

  @override
  Future<void> deletePost({
    required String postId,
    required String mediaUrl,
    String? thumbnailUrl,
  }) async {
    await _posts.doc(postId).delete();
    try {
      await _storage.refFromURL(mediaUrl).delete();
    } catch (_) {
      // Best-effort — the Firestore doc is already gone either way, and
      // an orphaned Storage object isn't worth failing the delete over.
    }
    if (thumbnailUrl != null) {
      try {
        await _storage.refFromURL(thumbnailUrl).delete();
      } catch (_) {
        // Same best-effort reasoning as the mediaUrl delete above.
      }
    }
  }

  @override
  Stream<bool> watchIsLikedByMe(String postId, String uid) {
    return _posts
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  @override
  Future<void> toggleLike({
    required String postId,
    required String uid,
    required bool like,
  }) {
    final likeRef = _posts.doc(postId).collection('likes').doc(uid);
    if (like) {
      return likeRef.set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return likeRef.delete();
  }

  @override
  Stream<bool> watchIsRepostedByMe(String postId, String uid) {
    return _users
        .doc(uid)
        .collection('reposts')
        .doc(postId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  @override
  Future<void> toggleRepost({
    required String postId,
    required String uid,
    required bool repost,
  }) {
    final repostRef = _users.doc(uid).collection('reposts').doc(postId);
    if (repost) {
      return repostRef.set({'createdAt': FieldValue.serverTimestamp()});
    }
    return repostRef.delete();
  }

  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _posts.doc(postId).collection('comments');

  @override
  Stream<List<PostComment>> watchComments(String postId) {
    // Ascending — top-level comments and their replies read top-to-
    // bottom in the order they were posted, like a conversation.
    return _comments(postId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => _commentFromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> addComment({
    required String postId,
    required String uid,
    required String text,
    String? replyToCommentId,
  }) {
    return _comments(postId).add({
      'userId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
      if (replyToCommentId != null) 'replyToCommentId': replyToCommentId,
    });
  }

  @override
  Future<void> updateComment({
    required String postId,
    required String commentId,
    required String text,
  }) {
    return _comments(postId).doc(commentId).update({'text': text});
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) {
    return _comments(postId).doc(commentId).delete();
  }

  @override
  Stream<bool> watchIsCommentLikedByMe(
    String postId,
    String commentId,
    String uid,
  ) {
    return _comments(postId)
        .doc(commentId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  @override
  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required String uid,
    required bool like,
  }) {
    final likeRef = _comments(
      postId,
    ).doc(commentId).collection('likes').doc(uid);
    if (like) {
      return likeRef.set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return likeRef.delete();
  }

  Post _fromDoc(String id, Map<String, dynamic> data) {
    return Post(
      id: id,
      userId: data['userId'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String? ?? '',
      mediaType: (data['mediaType'] as String?) == 'video'
          ? PostMediaType.video
          : PostMediaType.photo,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      caption: data['caption'] as String? ?? '',
    );
  }

  PostComment _commentFromDoc(String id, Map<String, dynamic> data) {
    return PostComment(
      id: id,
      userId: data['userId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      replyToCommentId: data['replyToCommentId'] as String?,
    );
  }
}
