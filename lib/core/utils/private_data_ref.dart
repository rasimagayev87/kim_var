import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/private/data` — the owner-only subcollection doc that
/// holds every PII/sensitive field split off `users/{uid}` in Düzəliş
/// Prompt 4 (K-1): email, phoneNumber, birthDate, gender, city, lat,
/// lng, fcmTokens, knownDeviceSignatures, consent, discoverRadiusMode/Km,
/// visibilityRadiusMode/Km, showReadReceipts, twoFactorEnabled,
/// ghostModeEnabled, incognitoBrowsingEnabled, notificationPreferences,
/// mapLocationSettings, activeChatId, activeCheckinVenueId,
/// lastVisitorsCheckedAt, premiumExpiresAt, loginProvider,
/// appVersion/buildNumber/platform/osVersion/lastSeenAt. Also
/// `blockedByUsers` (Düzəliş Prompt 5 / K-3) — the reverse of the
/// public `blockedUsers` array, trigger-maintained (`onUserUpdated`,
/// functions/src/index.ts), read only to filter this user's OWN feeds.
/// `firestore.rules` restricts this doc to `request.auth.uid == uid` —
/// no other user, and no client-side code outside the owner's own
/// session, can ever read or write it.
///
/// `country`, `blockedUsers`, `reportedCount`, `birthdayOffersOptIn`... —
/// see `privateDataRef` in `functions/src/index.ts` for the fields that
/// deliberately stayed PUBLIC despite being personal, because a
/// Cloud Function needs a top-level `.where()` on them (Firestore can't
/// query across a parent/subcollection split).
///
/// `showOnlineStatus` — REMOVED (Düzəliş Prompt 5 / RT-24), never
/// migrated here at all — see `FirebasePrivacySettingsRepository`'s own
/// doc comment for why.
DocumentReference<Map<String, dynamic>> privateDataRef(
  String uid, {
  FirebaseFirestore? firestore,
}) => (firestore ?? FirebaseFirestore.instance)
    .collection('users')
    .doc(uid)
    .collection('private')
    .doc('data');
