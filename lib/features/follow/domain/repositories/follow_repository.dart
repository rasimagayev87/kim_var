import '../entities/follow_edge.dart';

/// A one-directional social-graph edge — distinct from `friends`
/// (mutual, request/accept), which already exists elsewhere in this
/// app. Following a `public` account is instant; following a
/// `private` one creates a `pending` edge that only counts once the
/// followee accepts it (see [acceptFollowRequest]) — see
/// `AccountPrivacy` in privacy_settings.dart.
abstract class FollowRepository {
  /// How many users follow [uid] — ACCEPTED edges only, pending
  /// requests never count (matches "yalnız təsdiqdən sonra təqibçi
  /// sayına əlavə olunur").
  Stream<int> watchFollowersCount(String uid);

  /// How many users [uid] follows — ACCEPTED edges only.
  Stream<int> watchFollowingCount(String uid);

  /// True once the edge is ACCEPTED — a still-pending request reads as
  /// false here (see [watchIsPending] for that state instead). A doc
  /// with no `status` field at all (every edge created before "Hesab
  /// gizliliyi") is treated as accepted.
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  });

  /// True while [followerId] has an outstanding, not-yet-accepted
  /// request to follow [followeeId] — drives the "İstək göndərildi"
  /// button state.
  Stream<bool> watchIsPending({
    required String followerId,
    required String followeeId,
  });

  /// One-shot, single-direction: does [viewerId] hold an ACCEPTED edge
  /// pointing at [ownerId]? What a `private` account's media grid,
  /// stories, and follow/follower lists are gated against — mirrors
  /// `firestore.rules`' `isAcceptedFollower` exactly.
  Future<bool> isAcceptedFollowerOf({
    required String viewerId,
    required String ownerId,
  });

  /// Creates the edge — `pending` when [requiresApproval] is true
  /// (the followee's account is `private`), `accepted` otherwise.
  Future<void> follow({
    required String followerId,
    required String followeeId,
    required bool requiresApproval,
  });

  /// Removes the edge — an accepted follow (unfollow) or the
  /// follower's own still-pending request (cancel).
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  });

  /// The followee approves [followerId]'s pending request — flips
  /// `status` to `accepted`. Only the followee may call this
  /// (enforced in `firestore.rules`).
  Future<void> acceptFollowRequest({
    required String followerId,
    required String followeeId,
  });

  /// The followee rejects [followerId]'s pending request — removes the
  /// doc outright (a fresh request later just creates a new one).
  Future<void> declineFollowRequest({
    required String followerId,
    required String followeeId,
  });

  /// One page of [uid]'s ACCEPTED followers, newest edge first —
  /// [startAfter] cursors off the previous page's last [FollowEdge.createdAt].
  Future<List<FollowEdge>> fetchFollowersPage(
    String uid, {
    DateTime? startAfter,
    int limit = 30,
  });

  /// One page of accounts [uid] ACCEPTED-follows, newest edge first.
  Future<List<FollowEdge>> fetchFollowingPage(
    String uid, {
    DateTime? startAfter,
    int limit = 30,
  });

  /// The followee removes an already-accepted follower — same
  /// underlying delete as [unfollow]/[declineFollowRequest], kept as
  /// its own method since the app-level intent ("Çıxart") differs from
  /// either of those.
  Future<void> removeFollower({
    required String followerId,
    required String followeeId,
  });
}
