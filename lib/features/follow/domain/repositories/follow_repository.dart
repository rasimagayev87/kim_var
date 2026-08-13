/// A one-directional social-graph edge — distinct from `friends`
/// (mutual, request/accept), which already exists elsewhere in this
/// app. Following someone requires no action on their part.
abstract class FollowRepository {
  /// How many users follow [uid].
  Stream<int> watchFollowersCount(String uid);

  /// How many users [uid] follows.
  Stream<int> watchFollowingCount(String uid);

  Stream<bool> watchIsFollowing({required String followerId, required String followeeId});

  /// True if either direction of the edge exists between [uidA]/[uidB]
  /// — the same "counts either way" rule already used for
  /// `ProfileVisibility.followersOnly` and `WhoCanMessageMe.followersOnly`,
  /// and for `StoryVisibility.followers` (see `firestore.rules`'
  /// `isFollowingOrFollowedBy`, which this mirrors exactly). One-shot,
  /// not a stream — callers filtering a list (e.g. story visibility)
  /// need a point-in-time answer per item, not a live subscription per
  /// candidate.
  Future<bool> isFollowingOrFollowedBy(String uidA, String uidB);

  Future<void> follow({required String followerId, required String followeeId});

  Future<void> unfollow({required String followerId, required String followeeId});
}
