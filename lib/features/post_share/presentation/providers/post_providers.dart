import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/post.dart';

class PostComment {
  final String id;
  final String userId;
  final String text;
  final String? replyToCommentId;
  final int likesCount;
  final DateTime? createdAt;

  const PostComment({
    required this.id,
    required this.userId,
    required this.text,
    this.replyToCommentId,
    this.likesCount = 0,
    this.createdAt,
  });
}

Post _postFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return Post(
    id: doc.id,
    userId: data['userId'] as String? ?? '',
    mediaUrl: data['mediaUrl'] as String? ?? '',
    mediaType: (data['mediaType'] as String?) == 'video' ? PostMediaType.video : PostMediaType.photo,
    caption: data['caption'] as String? ?? '',
    likesCount: data['likesCount'] as int? ?? 0,
    commentsCount: data['commentsCount'] as int? ?? 0,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
  );
}

PostComment _commentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return PostComment(
    id: doc.id,
    userId: data['userId'] as String? ?? '',
    text: data['text'] as String? ?? '',
    replyToCommentId: data['replyToCommentId'] as String?,
    likesCount: data['likesCount'] as int? ?? 0,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
  );
}

/// Every post, newest first — the vertical "Lent" feed's data source.
final feedPostsProvider = StreamProvider<List<Post>>((ref) {
  return FirebaseFirestore.instance
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(_postFromDoc).toList());
});

/// One user's own posts, newest first — backs the grid on
/// [UserProfileScreen]. Sorted client-side rather than via a second
/// `orderBy` so this doesn't need its own Firestore composite index
/// alongside [feedPostsProvider]'s.
final postsByUserProvider = StreamProvider.family<List<Post>, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: uid).snapshots().map((snap) {
    final posts = snap.docs.map(_postFromDoc).toList();
    posts.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return posts;
  });
});

final commentsForPostProvider = StreamProvider.family<List<PostComment>, String>((ref, postId) {
  return FirebaseFirestore.instance
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs.map(_commentFromDoc).toList());
});

/// Whether the CURRENT user has liked [postId] — backs the feed's
/// heart icon. `posts/{postId}/likes/{uid}` existing IS the "liked"
/// signal (see firestore.rules).
final isPostLikedByMeProvider = StreamProvider.family<bool, String>((ref, postId) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('posts')
      .doc(postId)
      .collection('likes')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists);
});

final postControllerProvider = Provider<PostController>((ref) => PostController());

class PostController {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  PostController({FirebaseFirestore? firestore, fb.FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  /// Creates/deletes the caller's own `likes/{uid}` doc — the Cloud
  /// Function trigger fans that into `posts/{postId}.likesCount`.
  Future<bool> toggleLike(String postId, bool like) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final likeRef = _firestore.collection('posts').doc(postId).collection('likes').doc(uid);
      if (like) {
        await likeRef.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await likeRef.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addComment(String postId, String text, {String? replyToCommentId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _firestore.collection('posts').doc(postId).collection('comments').add({
        'userId': uid,
        'text': text,
        'replyToCommentId': replyToCommentId,
        'likesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      await _firestore.collection('posts').doc(postId).collection('comments').doc(commentId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
