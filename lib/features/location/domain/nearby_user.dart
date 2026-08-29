import '../../../core/utils/presence_utils.dart';

class NearbyUser {
  final String id;
  final String name;
  final String? username;
  final double lat;
  final double lng;
  final String bio;
  final String? photoUrl;
  final double distanceMeters;
  final bool online;
  final int? age;
  final DateTime? lastSeen;

  const NearbyUser({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.username,
    this.bio = '',
    this.photoUrl,
    this.online = false,
    this.age,
    this.lastSeen,
  });

  /// "İndi aktivdir" — see `isRecentlyOnline`'s doc comment for why
  /// this checks staleness rather than trusting [online] on its own.
  bool get isRecentlyActive => isRecentlyOnline(online: online, lastSeen: lastSeen);
}
