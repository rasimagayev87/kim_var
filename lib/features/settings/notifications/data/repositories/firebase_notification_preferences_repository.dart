import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

class FirebaseNotificationPreferencesRepository implements NotificationPreferencesRepository {
  FirebaseNotificationPreferencesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  @override
  Stream<NotificationPreferences> watchPreferences(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final map = snap.data()?['notificationPreferences'] as Map<String, dynamic>?;
      if (map == null) return const NotificationPreferences();
      return NotificationPreferences(
        messages: map['messages'] as bool? ?? true,
        followers: map['followers'] as bool? ?? true,
        newUsers: map['newUsers'] as bool? ?? true,
        likes: map['likes'] as bool? ?? true,
        comments: map['comments'] as bool? ?? true,
        venueOffers: map['venueOffers'] as bool? ?? true,
        venueUpdates: map['venueUpdates'] as bool? ?? true,
        security: map['security'] as bool? ?? true,
        systemNotifications: map['systemNotifications'] as bool? ?? true,
        marketing: map['marketing'] as bool? ?? false,
        pushEnabled: map['pushEnabled'] as bool? ?? true,
        emailEnabled: map['emailEnabled'] as bool? ?? false,
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
