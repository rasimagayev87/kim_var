import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_remote_datasource.dart';

/// A single [WriteBatch] can hold at most 500 operations — real accounts
/// can plausibly have more unread/read notifications than that, so bulk
/// operations chunk into batches of this size rather than assuming one
/// batch is always enough.
const _kBatchChunkSize = 450;

class FirebaseNotificationRemoteDatasource
    implements NotificationRemoteDatasource {
  FirebaseNotificationRemoteDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchNotifications(
    String uid, {
    required int limit,
  }) {
    return _notifications(
      uid,
    ).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> fetchMoreNotifications(
    String uid, {
    required DateTime startAfter,
    required int limit,
  }) {
    return _notifications(uid)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(startAfter)])
        .limit(limit)
        .get();
  }

  @override
  Future<void> markRead(String uid, String notificationId) {
    return _notifications(uid).doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllRead(String uid) async {
    final unread = await _notifications(
      uid,
    ).where('isRead', isEqualTo: false).get();
    await _runChunkedBatch(
      unread.docs,
      (batch, doc) => batch.update(doc.reference, {'isRead': true}),
    );
  }

  @override
  Future<void> deleteReadNotifications(String uid) async {
    final read = await _notifications(
      uid,
    ).where('isRead', isEqualTo: true).get();
    await _runChunkedBatch(
      read.docs,
      (batch, doc) => batch.delete(doc.reference),
    );
  }

  Future<void> _runChunkedBatch(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    void Function(
      WriteBatch batch,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    )
    apply,
  ) async {
    for (var i = 0; i < docs.length; i += _kBatchChunkSize) {
      final chunk = docs.skip(i).take(_kBatchChunkSize);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        apply(batch, doc);
      }
      await batch.commit();
    }
  }
}
