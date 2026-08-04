import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/firebase_notification_remote_datasource.dart';
import '../datasources/notification_remote_datasource.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({NotificationRemoteDatasource? datasource})
      : _datasource = datasource ?? FirebaseNotificationRemoteDatasource();

  final NotificationRemoteDatasource _datasource;

  @override
  Stream<List<AppNotification>> watchNotifications(String uid, {int limit = 30}) {
    return _datasource
        .watchNotifications(uid, limit: limit)
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<List<AppNotification>> fetchMoreNotifications(String uid, {required DateTime startAfter, int limit = 30}) async {
    final snap = await _datasource.fetchMoreNotifications(uid, startAfter: startAfter, limit: limit);
    return snap.docs.map((d) => _fromDoc(d.id, d.data())).toList();
  }

  @override
  Future<void> markRead(String uid, String notificationId) => _datasource.markRead(uid, notificationId);

  @override
  Future<void> markAllRead(String uid) => _datasource.markAllRead(uid);

  @override
  Future<void> deleteReadNotifications(String uid) => _datasource.deleteReadNotifications(uid);

  AppNotification _fromDoc(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      type: notificationTypeFromString(data['type'] as String? ?? ''),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      senderPhoto: data['senderPhoto'] as String?,
      targetId: data['targetId'] as String?,
      targetType: data['targetType'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deepLink: data['deepLink'] as String?,
      metadata: (data['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
