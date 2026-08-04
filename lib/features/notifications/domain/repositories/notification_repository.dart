import '../entities/notification.dart';

abstract class NotificationRepository {
  /// Realtime first page, newest first — not the whole history, so a
  /// very active account never pulls its entire notification log into
  /// one live listener. Older entries load on demand via
  /// [fetchMoreNotifications], matching this app's existing chat-list
  /// pagination pattern.
  Stream<List<AppNotification>> watchNotifications(String uid, {int limit});

  Future<List<AppNotification>> fetchMoreNotifications(String uid, {required DateTime startAfter, int limit});

  Future<void> markRead(String uid, String notificationId);

  Future<void> markAllRead(String uid);

  Future<void> deleteReadNotifications(String uid);
}
