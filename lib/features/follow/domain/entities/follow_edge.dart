/// One row of a followers/following list — the OTHER party's uid plus
/// the edge's own timestamp, which doubles as the pagination cursor
/// (see `FollowRepository.fetchFollowersPage`/`fetchFollowingPage`).
class FollowEdge {
  final String uid;
  final DateTime createdAt;

  const FollowEdge({required this.uid, required this.createdAt});
}
