import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw Firebase I/O boundary for the notifications feature — every
/// method here speaks Firestore primitives (snapshots, plain maps),
/// never the domain [AppNotification] type. Mapping happens in
/// [FirebaseNotificationRepository], not here.
///
/// There is deliberately no `createNotification` here: this app never
/// writes a notification doc from the client. Every entry in
/// `users/{uid}/notifications` is written server-side (Cloud Functions
/// reacting to follow/like/comment/venue events) — the client's whole
/// job is reading, marking read, and deleting, which is exactly the
/// surface below.
abstract class NotificationRemoteDatasource {
  /// Realtime first page, newest first — see
  /// [FirebaseNotificationRepository] for how this is merged with
  /// [fetchMoreNotifications]'s older, non-realtime pages.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchNotifications(
    String uid, {
    required int limit,
  });

  Future<QuerySnapshot<Map<String, dynamic>>> fetchMoreNotifications(
    String uid, {
    required DateTime startAfter,
    required int limit,
  });

  Future<void> markRead(String uid, String notificationId);

  Future<void> markAllRead(String uid);

  Future<void> deleteReadNotifications(String uid);
}
