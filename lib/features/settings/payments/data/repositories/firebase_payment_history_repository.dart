import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/payment_history_repository.dart';

class FirebasePaymentHistoryRepository implements PaymentHistoryRepository {
  FirebasePaymentHistoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  /// Reads the TOP-LEVEL `payments` collection, scoped to this user.
  ///
  /// This used to read `users/{uid}/payments` — a subcollection nothing
  /// has ever written to. Every server write goes to the root
  /// `payments` collection (sixteen call sites in
  /// functions/src/index.ts), so the Ödənişlər screen was empty for
  /// every user since the day it shipped: a real payment history,
  /// stored, readable, and pointed at the wrong path. Same defect class
  /// as BACKLOG #25 — a field moved (or in this case never lived where
  /// the reader looked) and the reader was never repointed.
  ///
  /// `firestore.rules` already allows exactly this query:
  /// `allow read: if request.auth.uid == resource.data.ownerId`, which
  /// a `where('ownerId', ...)` list query satisfies. Needs the
  /// `ownerId` + `createdAt` composite index (firestore.indexes.json).
  Stream<List<PaymentRecord>> watchHistory(String uid) {
    return _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  PaymentRecord _fromDoc(String id, Map<String, dynamic> data) {
    return PaymentRecord(
      id: id,
      type: _typeFrom(data['type'] as String?),
      // The root `payments` document has no `packageName`; its
      // human-readable label is `description`, written server-side at
      // charge time ("Məkan abunəliyi — X", "PinBox — Y", "Təklif
      // yerləşdirmə haqqı — Z"). Those are display strings, not slugs,
      // so they can be shown as-is — but they are AZERBAIJANI ONLY,
      // because they are composed on the server with no knowledge of
      // the reader's language. The screen therefore renders the
      // localized `type` label as the heading and this as the detail
      // line. See docs/BACKLOG.md.
      packageName:
          data['description'] as String? ??
          data['packageName'] as String? ??
          '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  PaymentRecordType _typeFrom(String? value) {
    return PaymentRecordType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => PaymentRecordType.purchase,
    );
  }
}
