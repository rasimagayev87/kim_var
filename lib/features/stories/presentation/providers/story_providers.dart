import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../follow/presentation/providers/follow_providers.dart';
import '../../../privacy/domain/entities/privacy_settings.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../../data/repositories/firebase_story_repository.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/story_view.dart';
import '../../domain/repositories/story_repository.dart';
import '../../domain/usecases/create_story_usecase.dart';

final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => FirebaseStoryRepository(),
);

final createStoryUseCaseProvider = Provider<CreateStoryUseCase>((ref) {
  return CreateStoryUseCase(ref.watch(storyRepositoryProvider));
});

/// The signed-in user's own active stories — drives both the
/// profile-tab ring (non-empty = show it) and the self-story viewer.
final myActiveStoriesProvider = StreamProvider.autoDispose<List<Story>>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(storyRepositoryProvider).watchMyActiveStories(uid);
});

/// Same query as [myActiveStoriesProvider] but for any [uid] — drives
/// the story ring on someone ELSE's profile screen. Gated entirely by
/// [uid]'s `AccountPrivacy` now (see "Hesab gizliliyi"), not a
/// per-story choice: `public` shows to everyone, `private` only to an
/// ACCEPTED follower (`isAcceptedFollowerOf`, one direction — the
/// viewer must follow [uid], not just have any follow edge with them).
/// `firestore.rules`' own `stories/{storyId}` read rule mirrors this
/// exactly and is the real access gate — verified directly against a
/// live authenticated client, not just read from the rules file. This
/// adds a second, client-side check on top of that: defense in depth,
/// and it also means a permission-denied on the underlying query
/// degrades to "no stories shown" instead of an error state.
final activeStoriesForUserProvider = StreamProvider.autoDispose
    .family<List<Story>, String>((ref, uid) {
      final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
      final followRepo = ref.watch(followRepositoryProvider);

      return ref
          .watch(storyRepositoryProvider)
          .watchMyActiveStories(uid)
          .asyncMap((stories) async {
            if (myUid == null || myUid == uid || stories.isEmpty)
              return stories;

            final privacy = await ref.read(
              otherUserPrivacySettingsProvider(uid).future,
            );
            if (privacy.accountPrivacy == AccountPrivacy.public) return stories;

            final allowed = await followRepo.isAcceptedFollowerOf(
              viewerId: myUid,
              ownerId: uid,
            );
            return allowed ? stories : const <Story>[];
          })
          .handleError((Object _, StackTrace _) => const <Story>[]);
    });

final storyViewsProvider = StreamProvider.autoDispose
    .family<List<StoryView>, String>((ref, storyId) {
      return ref.watch(storyRepositoryProvider).watchViews(storyId);
    });

class StoryController {
  StoryController(this._ref);

  final Ref _ref;

  /// Returns the new story's id on success, null on failure (logged
  /// internally). No visibility choice to make anymore — a story's
  /// audience is whatever the poster's own `AccountPrivacy` says at
  /// view time (see `activeStoriesForUserProvider`), not a per-post
  /// pick.
  Future<String?> createStory({
    required File media,
    required StoryMediaType mediaType,
    required void Function() onError,
  }) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      return await _ref
          .read(createStoryUseCaseProvider)
          .call(creatorId: uid, media: media, mediaType: mediaType);
    } catch (e, st) {
      logError('story_providers.createStory', e, st);
      onError();
      return null;
    }
  }

  /// Best-effort, fire-and-forget — a failed view write just means the
  /// creator's viewer list undercounts by one, not worth surfacing.
  Future<void> recordView(String storyId) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _ref
          .read(storyRepositoryProvider)
          .recordView(storyId: storyId, viewerId: uid);
    } catch (e, st) {
      logError('story_providers.recordView', e, st);
    }
  }

  /// Returns true on success (logged internally on failure).
  Future<bool> deleteStory(String storyId) async {
    try {
      await _ref.read(storyRepositoryProvider).deleteStory(storyId);
      return true;
    } catch (e, st) {
      logError('story_providers.deleteStory', e, st);
      return false;
    }
  }
}

final storyControllerProvider = Provider<StoryController>(
  (ref) => StoryController(ref),
);
