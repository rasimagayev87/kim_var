import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../../../core/utils/private_data_ref.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

/// `notificationPreferences` lives on `users/{uid}/private/data`
/// (Düzəliş Prompt 4) — see `privateDataRef`'s own doc comment.
class FirebaseNotificationPreferencesRepository implements NotificationPreferencesRepository {
  FirebaseNotificationPreferencesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return privateDataRef(uid, firestore: _firestore);
  }

  @override
  Stream<NotificationPreferences> watchPreferences(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final map = snap.data()?['notificationPreferences'] as Map<String, dynamic>?;
      if (map == null) return const NotificationPreferences();
      // Every default here MUST match the server's own reading of a
      // missing key. `notifyUser` treats absent as enabled
      // (`prefs[category] === false` is the only thing that blocks), so
      // every `?? true` below is the same answer the server gives.
      //
      // `marketing` is the exception and it is deliberate: promotional
      // messages are OPT-IN, so both sides default it to OFF. That
      // agreement is asserted by
      // `tests/rules/notification-categories.test.ts` — before this
      // pass the two disagreed, because `updatePreferences` only writes
      // keys the user actually touched, so an untouched `marketing` was
      // absent from Firestore and the admin broadcast's `!== false`
      // filter read that absence as consent.
      return NotificationPreferences(
        messages: map['messages'] as bool? ?? true,
        followers: map['followers'] as bool? ?? true,
        likes: map['likes'] as bool? ?? true,
        comments: map['comments'] as bool? ?? true,
        venueOffers: map['venueOffers'] as bool? ?? true,
        venueUpdates: map['venueUpdates'] as bool? ?? true,
        systemNotifications: map['systemNotifications'] as bool? ?? true,
        marketing: map['marketing'] as bool? ?? false,
        pushEnabled: map['pushEnabled'] as bool? ?? true,
      );
    });
  }

  @override
  Future<void> updatePreferences(String uid, Map<String, bool> changes) {
    final data = <String, dynamic>{
      for (final entry in changes.entries) 'notificationPreferences.${entry.key}': entry.value,
    };
    // Must be update(), not set(merge:true) — only update() interprets a
    // dotted key like 'notificationPreferences.messages' as a nested
    // field path. set(merge:true) writes it as one literal top-level
    // field whose name contains a dot, so the nested map watchPreferences
    // reads from never actually gets created — every toggle silently
    // no-ops and the read falls back to defaults (all true) forever.
    return _userDoc(uid).update(data);
  }

  @override
  Future<void> subscribeToTopic(String topic) {
    return FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) {
    return FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }
}
