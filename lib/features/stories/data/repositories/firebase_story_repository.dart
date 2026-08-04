import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/entities/story.dart';
import '../../domain/entities/story_view.dart';
import '../../domain/repositories/story_repository.dart';

class FirebaseStoryRepository implements StoryRepository {
  FirebaseStoryRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const _storyLifetime = Duration(hours: 24);

  CollectionReference<Map<String, dynamic>> get _stories => _firestore.collection('stories');

  @override
  Future<String> createStory({
    required String creatorId,
    required File media,
    required StoryMediaType mediaType,
    required StoryVisibility visibility,
  }) async {
    final ref = _stories.doc();
    final extension = mediaType == StoryMediaType.video ? 'mp4' : 'jpg';
    final contentType = mediaType == StoryMediaType.video ? 'video/mp4' : 'image/jpeg';

    final storageRef = _storage.ref('stories/$creatorId/${ref.id}.$extension');
    await storageRef.putFile(media, SettableMetadata(contentType: contentType));
    final mediaUrl = await storageRef.getDownloadURL();

    final now = DateTime.now();
    await ref.set({
      'creatorId': creatorId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      'visibility': visibility.name,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(_storyLifetime)),
    });

    return ref.id;
  }

  @override
  Stream<List<Story>> watchMyActiveStories(String uid) {
    return _stories
        .where('creatorId', isEqualTo: uid)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<void> deleteStory(String storyId) {
    return _stories.doc(storyId).delete();
  }

  @override
  Future<void> recordView({required String storyId, required String viewerId}) {
    return _stories.doc(storyId).collection('views').doc(viewerId).set({
      'viewerId': viewerId,
      'viewedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<StoryView>> watchViews(String storyId) {
    return _stories
        .doc(storyId)
        .collection('views')
        .orderBy('viewedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _viewFromDoc(d.id, d.data())).toList());
  }

  Story _fromDoc(String id, Map<String, dynamic> data) {
    return Story(
      id: id,
      creatorId: data['creatorId'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String? ?? '',
      mediaType: (data['mediaType'] as String?) == 'video' ? StoryMediaType.video : StoryMediaType.image,
      visibility: (data['visibility'] as String?) == 'everyone' ? StoryVisibility.everyone : StoryVisibility.followers,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  StoryView _viewFromDoc(String id, Map<String, dynamic> data) {
    return StoryView(
      viewerId: data['viewerId'] as String? ?? id,
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
