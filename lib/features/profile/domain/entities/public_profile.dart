import '../../../../core/utils/presence_utils.dart';

/// Another user's profile as seen from the outside (map/card stack,
/// chat header, etc.) — distinct from [UserProfile], which is always
/// the signed-in user's own editable profile. Deliberately carries no
/// `birthDate`/`gender` (moved to `users/{uid}/private/data` in Düzəliş
/// Prompt 4 — neither was ever displayed on any screen that reads this
/// entity, confirmed by grep, so nothing downstream needed them kept as
/// dead fields either).
class PublicProfile {
  final String id;
  final String name;
  final String? username;
  final String? photoUrl;
  final String bio;
  final bool online;
  final DateTime? lastSeen;
  final bool identityVerified;
  final bool premium;

  const PublicProfile({
    required this.id,
    required this.name,
    this.username,
    this.photoUrl,
    this.bio = '',
    this.online = false,
    this.lastSeen,
    this.identityVerified = false,
    this.premium = false,
  });

  /// Self-healing presence check — see [isRecentlyOnline].
  bool get isRecentlyActive => isRecentlyOnline(online: online, lastSeen: lastSeen);
}
