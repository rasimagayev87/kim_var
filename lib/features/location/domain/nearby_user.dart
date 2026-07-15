class NearbyUser {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String mainInterest;
  final String? photoUrl;
  final double distanceMeters;
  final bool online;

  const NearbyUser({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.mainInterest,
    required this.distanceMeters,
    this.photoUrl,
    this.online = false,
  });
}
