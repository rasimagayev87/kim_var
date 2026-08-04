class NearbyUser {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String bio;
  final String? photoUrl;
  final double distanceMeters;
  final bool online;
  final int? age;
  final String? gender;
  final int starCount;
  final int heartCount;
  final int dislikeCount;
  final DateTime? lastSeen;

  const NearbyUser({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.bio = '',
    this.photoUrl,
    this.online = false,
    this.age,
    this.gender,
    this.starCount = 0,
    this.heartCount = 0,
    this.dislikeCount = 0,
    this.lastSeen,
  });

  /// "İndi aktivdir" — active within the last 5 minutes, per spec.
  bool get isRecentlyActive =>
      lastSeen != null && DateTime.now().difference(lastSeen!) <= const Duration(minutes: 5);
}
