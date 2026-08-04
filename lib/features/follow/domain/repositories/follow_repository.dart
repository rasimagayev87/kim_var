/// A one-directional social-graph edge — distinct from `friends`
/// (mutual, request/accept), which already exists elsewhere in this
/// app. Following someone requires no action on their part.
abstract class FollowRepository {
  /// How many users follow [uid].
  Stream<int> watchFollowersCount(String uid);

  /// How many users [uid] follows.
  Stream<int> watchFollowingCount(String uid);

  Stream<bool> watchIsFollowing({required String followerId, required String followeeId});

  Future<void> follow({required String followerId, required String followeeId});

  Future<void> unfollow({required String followerId, required String followeeId});
}
