import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/privacy_settings.dart';
import '../../domain/repositories/privacy_settings_repository.dart';

/// Backed by flat fields on the same `users/{uid}` document every other
/// profile field already lives on (matches `blockedUsers`, `premium`,
/// `online`, ...) — not a separate collection. Docs created before this
/// feature existed simply don't have these fields yet, so every read
/// below falls back to [PrivacySettings]'s own defaults.
class FirebasePrivacySettingsRepository implements PrivacySettingsRepository {
  FirebasePrivacySettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  @override
  Stream<PrivacySettings> watchSettings(String uid) {
    return _users.doc(uid).snapshots().map((doc) => _fromDoc(doc.data()));
  }

  @override
  Future<void> updateSettings(String uid, Map<String, dynamic> patch) {
    return _users.doc(uid).set(patch, SetOptions(merge: true));
  }

  PrivacySettings _fromDoc(Map<String, dynamic>? data) {
    if (data == null) return const PrivacySettings();

    final radiusMode = _radiusModeFrom(data['visibilityRadiusMode'] as String?);
    return PrivacySettings(
      profileVisibility: _visibilityFrom(data['profileVisibility'] as String?),
      visibilityRadiusMode: radiusMode,
      visibilityRadiusKm:
          radiusMode == VisibilityRadiusMode.distance ? (data['visibilityRadiusKm'] as num?)?.toDouble() ?? 1.0 : null,
      showOnlineStatus: data['showOnlineStatus'] as bool? ?? true,
      showReadReceipts: data['showReadReceipts'] as bool? ?? true,
      whoCanMessageMe: _whoCanMessageMeFrom(data['whoCanMessageMe'] as String?),
      twoFactorEnabled: data['twoFactorEnabled'] as bool? ?? false,
      ghostModeEnabled: data['ghostModeEnabled'] as bool? ?? false,
      birthdayOffersOptIn: data['birthdayOffersOptIn'] as bool? ?? false,
    );
  }

  ProfileVisibility _visibilityFrom(String? value) {
    return ProfileVisibility.values.firstWhere((v) => v.name == value, orElse: () => ProfileVisibility.everyone);
  }

  VisibilityRadiusMode _radiusModeFrom(String? value) {
    return VisibilityRadiusMode.values.firstWhere((v) => v.name == value, orElse: () => VisibilityRadiusMode.distance);
  }

  WhoCanMessageMe _whoCanMessageMeFrom(String? value) {
    return WhoCanMessageMe.values.firstWhere((v) => v.name == value, orElse: () => WhoCanMessageMe.everyone);
  }
}
