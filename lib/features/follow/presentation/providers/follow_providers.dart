import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/repositories/firebase_follow_repository.dart';
import '../../domain/repositories/follow_repository.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) => FirebaseFollowRepository());

/// How many users follow [uid] — works for the signed-in user's own
/// profile (`profile_tab.dart`) or anyone else's (`user_profile_screen.dart`).
final followersCountProvider = StreamProvider.autoDispose.family<int, String>((ref, uid) {
  return ref.watch(followRepositoryProvider).watchFollowersCount(uid);
});

/// How many users [uid] follows.
final followingCountProvider = StreamProvider.autoDispose.family<int, String>((ref, uid) {
  return ref.watch(followRepositoryProvider).watchFollowingCount(uid);
});

/// Whether the signed-in user follows [otherUid] — drives the
/// Follow/Following button state on someone else's profile.
final isFollowingProvider = StreamProvider.autoDispose.family<bool, String>((ref, otherUid) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsFollowing(followerId: myUid, followeeId: otherUid);
});

/// The reverse direction — whether [otherUid] follows the signed-in
/// user. Combined with [isFollowingProvider], this is what a
/// "Təqib/Təqibçilər" (either-direction) media-visibility check needs;
/// neither one alone is enough.
final isFollowedByProvider = StreamProvider.autoDispose.family<bool, String>((ref, otherUid) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsFollowing(followerId: otherUid, followeeId: myUid);
});

class FollowController {
  FollowController(this._ref);

  final Ref _ref;

  /// Returns true on success. Never throws — matches every other
  /// controller in this app (see `FriendController.sendRequest`):
  /// failures are logged internally so the button can show one
  /// friendly message instead of a raw exception.
  Future<bool> toggleFollow({required String otherUid, required bool isCurrentlyFollowing}) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;

    try {
      if (isCurrentlyFollowing) {
        await _ref.read(followRepositoryProvider).unfollow(followerId: myUid, followeeId: otherUid);
      } else {
        await _ref.read(followRepositoryProvider).follow(followerId: myUid, followeeId: otherUid);
      }
      return true;
    } catch (e, st) {
      logError('follow_providers.toggleFollow', e, st);
      return false;
    }
  }
}

final followControllerProvider = Provider<FollowController>((ref) => FollowController(ref));
