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

/// Whether the signed-in user follows [otherUid] — ACCEPTED only.
/// Drives the Follow/Following button state, and (via `AccountPrivacy
/// .private`) whether their media/stories are visible.
final isFollowingProvider = StreamProvider.autoDispose.family<bool, String>((ref, otherUid) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsFollowing(followerId: myUid, followeeId: otherUid);
});

/// Whether the signed-in user has an outstanding, not-yet-accepted
/// request to follow [otherUid] — drives the "İstək göndərildi" button
/// state on a `private` account's profile.
final isPendingFollowRequestProvider = StreamProvider.autoDispose.family<bool, String>((ref, otherUid) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsPending(followerId: myUid, followeeId: otherUid);
});

/// Whether [otherUid] has sent the signed-in user a still-pending
/// follow request — true here means `UserProfileScreen` should show
/// Accept/Decline instead of the normal Follow button (this is exactly
/// the profile a `followRequest` notification's "profile" targetType
/// deep-links to).
final incomingFollowRequestProvider = StreamProvider.autoDispose.family<bool, String>((ref, otherUid) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsPending(followerId: otherUid, followeeId: myUid);
});

class FollowController {
  FollowController(this._ref);

  final Ref _ref;

  /// Returns true on success. Never throws — matches every other
  /// controller in this app (see `FriendController.sendRequest`):
  /// failures are logged internally so the button can show one
  /// friendly message instead of a raw exception.
  ///
  /// [isCurrentlyFollowing]/[isCurrentlyPending] decide unfollow vs.
  /// cancel-request vs. new-follow; [otherAccountIsPrivate] decides
  /// whether a brand-new edge starts `pending` (needs the followee's
  /// approval) or `accepted` (instant) — see `AccountPrivacy`.
  Future<bool> toggleFollow({
    required String otherUid,
    required bool isCurrentlyFollowing,
    required bool isCurrentlyPending,
    required bool otherAccountIsPrivate,
  }) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;

    try {
      if (isCurrentlyFollowing || isCurrentlyPending) {
        await _ref.read(followRepositoryProvider).unfollow(followerId: myUid, followeeId: otherUid);
      } else {
        await _ref
            .read(followRepositoryProvider)
            .follow(followerId: myUid, followeeId: otherUid, requiresApproval: otherAccountIsPrivate);
      }
      return true;
    } catch (e, st) {
      logError('follow_providers.toggleFollow', e, st);
      return false;
    }
  }

  /// Returns true on success (logged internally on failure). [otherUid]
  /// is the REQUESTER — the profile `UserProfileScreen` is currently
  /// showing Accept/Decline for.
  Future<bool> acceptFollowRequest(String otherUid) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;
    try {
      await _ref.read(followRepositoryProvider).acceptFollowRequest(followerId: otherUid, followeeId: myUid);
      return true;
    } catch (e, st) {
      logError('follow_providers.acceptFollowRequest', e, st);
      return false;
    }
  }

  Future<bool> declineFollowRequest(String otherUid) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;
    try {
      await _ref.read(followRepositoryProvider).declineFollowRequest(followerId: otherUid, followeeId: myUid);
      return true;
    } catch (e, st) {
      logError('follow_providers.declineFollowRequest', e, st);
      return false;
    }
  }
}

final followControllerProvider = Provider<FollowController>((ref) => FollowController(ref));
