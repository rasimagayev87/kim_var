import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../../core/utils/app_logger.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firebase_notification_preferences_repository.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

const Map<String, String> notificationCategoryTopics = {
  'messages': 'messages',
  'followers': 'followers',
  'newUsers': 'new_users',
  'likes': 'likes',
  'comments': 'comments',
  'venueOffers': 'venue_offers',
  'venueUpdates': 'venue_updates',
  'security': 'security',
  'systemNotifications': 'system',
  'marketing': 'marketing',
};

final notificationPreferencesRepositoryProvider = Provider<NotificationPreferencesRepository>((ref) {
  return FirebaseNotificationPreferencesRepository();
});

/// The OS-level permission — separate from [NotificationPreferences],
/// which is this app's own stored preference and stays "on" regardless
/// of whether the OS is actually allowed to show anything. Backs the
/// Bildirişlər screen's "denied, go to Settings" banner: a user who
/// denied the permission once has no other way to discover why push
/// never arrives, since every in-app toggle still reads as enabled.
final notificationPermissionStatusProvider = FutureProvider.autoDispose<ph.PermissionStatus>((ref) {
  return ph.Permission.notification.status;
});

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final notificationPreferencesProvider = StreamProvider.autoDispose<NotificationPreferences>((ref) {
  // Forces a rebuild on sign-out/sign-in — without it, a quick account
  // switch can resurrect this provider still bound to the previous
  // uid before autoDispose's own teardown-triggered disposal fires,
  // silently showing the PREVIOUS account's notification toggles
  // under the new session. Same fix pattern as
  // `chatListControllerProvider`/`_premiumStatusProvider`.
  ref.watch(authStateProvider);
  final uid = _currentUid();
  if (uid == null) return Stream.value(const NotificationPreferences());
  return ref.watch(notificationPreferencesRepositoryProvider).watchPreferences(uid);
});

/// Every toggle on the Bildirişlər screen goes through here. Category
/// toggles and the push master toggle keep the on-device FCM topic
/// subscriptions in sync with Firestore; the email toggle is
/// Firestore-only — no transactional email service is wired up yet
/// (same gap as the Hesab screen's email-change feature), so it's a
/// real stored preference that nothing currently acts on.
class NotificationPreferencesController {
  NotificationPreferencesController(this._ref);

  final Ref _ref;

  Future<bool> toggleCategory(String key, bool value, bool pushEnabled) async {
    final uid = _currentUid();
    if (uid == null) return false;
    final repo = _ref.read(notificationPreferencesRepositoryProvider);
    try {
      await repo.updatePreferences(uid, {key: value});
      final topic = notificationCategoryTopics[key];
      if (pushEnabled && topic != null) {
        if (value) {
          await repo.subscribeToTopic(topic);
        } else {
          await repo.unsubscribeFromTopic(topic);
        }
      }
      return true;
    } catch (e, st) {
      logError('notification_providers.NotificationPreferencesController.toggleCategory', e, st);
      return false;
    }
  }

  Future<bool> togglePush(bool value, NotificationPreferences current) async {
    final uid = _currentUid();
    if (uid == null) return false;
    final repo = _ref.read(notificationPreferencesRepositoryProvider);
    try {
      await repo.updatePreferences(uid, {'pushEnabled': value});
      for (final entry in notificationCategoryTopics.entries) {
        if (!current.categoryValue(entry.key)) continue;
        if (value) {
          await repo.subscribeToTopic(entry.value);
        } else {
          await repo.unsubscribeFromTopic(entry.value);
        }
      }
      return true;
    } catch (e, st) {
      logError('notification_providers.NotificationPreferencesController.togglePush', e, st);
      return false;
    }
  }

  Future<bool> toggleEmail(bool value) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(notificationPreferencesRepositoryProvider).updatePreferences(uid, {'emailEnabled': value});
      return true;
    } catch (e, st) {
      logError('notification_providers.NotificationPreferencesController.toggleEmail', e, st);
      return false;
    }
  }

  /// Called once at app start. Requests notification permission (iOS
  /// requires this explicitly; Android 13+ too), reconciles actual FCM
  /// topic subscriptions against the stored Firestore preferences (so a
  /// fresh install or a preference changed on another device ends up
  /// subscribed correctly on this device too), and registers this
  /// device's FCM token — the token is what
  /// `onChatMessageCreated` (Cloud Functions) actually sends chat-message
  /// pushes to; topics alone can't target one specific recipient.
  Future<void> syncSubscriptions() async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final repo = _ref.read(notificationPreferencesRepositoryProvider);
      final prefs = await repo.watchPreferences(uid).first;
      for (final entry in notificationCategoryTopics.entries) {
        final shouldSubscribe = prefs.pushEnabled && prefs.categoryValue(entry.key);
        if (shouldSubscribe) {
          await repo.subscribeToTopic(entry.value);
        } else {
          await repo.unsubscribeFromTopic(entry.value);
        }
      }
      await _registerFcmToken(uid);
    } catch (e, st) {
      logError('notification_providers.NotificationPreferencesController.syncSubscriptions', e, st);
    }
  }

  /// Stores this device's current token on `users/{uid}/private/data.
  /// fcmTokens` (Düzəliş Prompt 4 — an array; a signed-in-on-multiple-
  /// devices user should get pushes on all of them) and keeps listening
  /// for token refreshes, which FCM issues periodically/on reinstall
  /// for the lifetime of the app.
  Future<void> _registerFcmToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _addToken(token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _addToken(newToken);
    });
  }

  /// P0 / H-9 — goes through the `registerFcmToken` Cloud Function
  /// instead of writing `fcmTokens` directly. That array is the input
  /// to `messaging.sendEachForMulticast`, so a client-writable list of
  /// push targets meant an account could insert ANOTHER user's device
  /// token and have its own notifications delivered there;
  /// `firestore.rules` now blocks the field outright.
  Future<void> _addToken(String token) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('registerFcmToken')
          .call<Map<String, dynamic>>({'token': token});
    } catch (e, st) {
      logError('notification_providers.NotificationPreferencesController._addToken', e, st);
    }
  }

  /// Best-effort removal of this device's token — call BEFORE signing
  /// out (needs `request.auth.uid == userId` to still hold for the
  /// write) so a signed-out device stops receiving pushes meant for
  /// whoever signs in next on it. Failures are swallowed (logged only)
  /// — a stale token left behind isn't worth blocking sign-out over,
  /// and gets pruned automatically anyway once it starts bouncing (see
  /// `onChatMessageCreated`'s stale-token cleanup).
  Future<void> unregisterFcmToken() async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      // P0 / H-9 — see `_addToken` above. Deliberately still called
      // BEFORE sign-out: the callable needs a live `request.auth`.
      await FirebaseFunctions.instance
          .httpsCallable('unregisterFcmToken')
          .call<Map<String, dynamic>>({'token': token});
    } catch (e, st) {
      logError('notification_providers.NotificationPreferencesController.unregisterFcmToken', e, st);
    }
  }
}

final notificationPreferencesControllerProvider = Provider<NotificationPreferencesController>((ref) {
  return NotificationPreferencesController(ref);
});
