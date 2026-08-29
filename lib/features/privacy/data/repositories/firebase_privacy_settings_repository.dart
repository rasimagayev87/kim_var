import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/private_data_ref.dart';
import '../../domain/entities/privacy_settings.dart';
import '../../domain/repositories/privacy_settings_repository.dart';

/// `profileVisibility`/`accountPrivacy`/`whoCanMessageMe`/
/// `birthdayOffersOptIn` stay on the public `users/{uid}` doc (rules-
/// engine `get()` calls read `accountPrivacy` regardless of where it
/// lives; `birthdayOffersOptIn` is queried top-level by
/// `computeBirthdayMatches`, which structurally can't cross a
/// parent/subcollection split; `whoCanMessageMe` is a policy value, not
/// content — its real server-side enforcement (Düzəliş Prompt 5, RT-6)
/// reads it straight off this public doc via `firestore.rules`'
/// `canMessage()`, so keeping it here is what makes that possible with
/// no extra read). Everything else here (`visibilityRadiusMode/Km`,
/// `showReadReceipts`, `twoFactorEnabled`, `ghostModeEnabled`,
/// `incognitoBrowsingEnabled`) moved to `users/{uid}/private/data` —
/// see `privateDataRef`'s own doc comment for the full field list.
///
/// `showOnlineStatus` — REMOVED (Düzəliş Prompt 5 / RT-24), not moved.
/// It was never actually read anywhere except to gate the OWNER's own
/// presence write (`PresenceController._write`); no consumer ever hid
/// `online`/`lastSeen` from OTHER users based on it, so the toggle was
/// a false promise — see `PresenceController`'s own doc comment for
/// the fuller reasoning and why a real fix would need a much larger
/// architecture change (moving every single-profile read, not just
/// scan-based ones, through a server funnel) deferred as a separate,
/// future prompt rather than half-built here.
class FirebasePrivacySettingsRepository implements PrivacySettingsRepository {
  FirebasePrivacySettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _privateKeys = {
    'visibilityRadiusMode',
    'visibilityRadiusKm',
    'showReadReceipts',
    'twoFactorEnabled',
    'ghostModeEnabled',
    'incognitoBrowsingEnabled',
  };

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  @override
  Stream<PrivacySettings> watchSettings(String uid) {
    Map<String, dynamic>? publicData;
    Map<String, dynamic>? privateData;
    late final StreamController<PrivacySettings> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? publicSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? privateSub;

    controller = StreamController<PrivacySettings>(
      onListen: () {
        publicSub = _users.doc(uid).snapshots().listen((doc) {
          publicData = doc.data();
          controller.add(_fromDocs(publicData, privateData));
        }, onError: controller.addError);
        privateSub = privateDataRef(uid, firestore: _firestore).snapshots().listen((doc) {
          privateData = doc.data();
          controller.add(_fromDocs(publicData, privateData));
        }, onError: controller.addError);
      },
      onCancel: () async {
        await publicSub?.cancel();
        await privateSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> updateSettings(String uid, Map<String, dynamic> patch) async {
    final privatePatch = <String, dynamic>{};
    final publicPatch = <String, dynamic>{};
    patch.forEach((key, value) {
      (_privateKeys.contains(key) ? privatePatch : publicPatch)[key] = value;
    });

    final batch = _firestore.batch();
    if (publicPatch.isNotEmpty) {
      batch.set(_users.doc(uid), publicPatch, SetOptions(merge: true));
    }
    if (privatePatch.isNotEmpty) {
      batch.set(privateDataRef(uid, firestore: _firestore), privatePatch, SetOptions(merge: true));
    }
    await batch.commit();
  }

  PrivacySettings _fromDocs(Map<String, dynamic>? publicData, Map<String, dynamic>? privateData) {
    if (publicData == null) return const PrivacySettings();

    final radiusMode = _radiusModeFrom(privateData?['visibilityRadiusMode'] as String?);
    return PrivacySettings(
      profileVisibility: _visibilityFrom(publicData['profileVisibility'] as String?),
      accountPrivacy: _accountPrivacyFrom(publicData['accountPrivacy'] as String?),
      visibilityRadiusMode: radiusMode,
      visibilityRadiusKm: radiusMode == VisibilityRadiusMode.distance
          ? (privateData?['visibilityRadiusKm'] as num?)?.toDouble() ?? 1.0
          : null,
      showReadReceipts: privateData?['showReadReceipts'] as bool? ?? true,
      whoCanMessageMe: _whoCanMessageMeFrom(publicData['whoCanMessageMe'] as String?),
      twoFactorEnabled: privateData?['twoFactorEnabled'] as bool? ?? false,
      ghostModeEnabled: privateData?['ghostModeEnabled'] as bool? ?? false,
      birthdayOffersOptIn: publicData['birthdayOffersOptIn'] as bool? ?? false,
      incognitoBrowsingEnabled: privateData?['incognitoBrowsingEnabled'] as bool? ?? false,
    );
  }

  ProfileVisibility _visibilityFrom(String? value) {
    return ProfileVisibility.values.firstWhere((v) => v.name == value, orElse: () => ProfileVisibility.everyone);
  }

  AccountPrivacy _accountPrivacyFrom(String? value) {
    return AccountPrivacy.values.firstWhere((v) => v.name == value, orElse: () => AccountPrivacy.public);
  }

  VisibilityRadiusMode _radiusModeFrom(String? value) {
    return VisibilityRadiusMode.values.firstWhere((v) => v.name == value, orElse: () => VisibilityRadiusMode.distance);
  }

  WhoCanMessageMe _whoCanMessageMeFrom(String? value) {
    return WhoCanMessageMe.values.firstWhere((v) => v.name == value, orElse: () => WhoCanMessageMe.everyone);
  }
}
