import 'dart:io';

import '../entities/story.dart';
import '../entities/story_view.dart';

abstract class StoryRepository {
  /// Uploads [media] to Storage then creates the story doc; returns the
  /// new story's id. `expiresAt` is always `createdAt + 24h`, set
  /// server-side by the implementation — callers don't specify it.
  Future<String> createStory({required String creatorId, required File media, required StoryMediaType mediaType});

  /// The signed-in user's own non-expired stories, soonest-to-expire
  /// first — may be more than one (see the "+" add-another-story
  /// affordance). Expiry is filtered server-side in the query itself.
  Stream<List<Story>> watchMyActiveStories(String uid);

  Future<void> deleteStory(String storyId);

  /// Records that [viewerId] has seen [storyId] — one doc per
  /// (story, viewer) pair, so repeat views don't grow the list.
  Future<void> recordView({required String storyId, required String viewerId});

  /// Newest-first. Readable only by the story's own creator — see
  /// `firestore.rules`.
  Stream<List<StoryView>> watchViews(String storyId);
}
