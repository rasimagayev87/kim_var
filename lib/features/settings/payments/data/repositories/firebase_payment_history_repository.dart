import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/payment_history_repository.dart';

class FirebasePaymentHistoryRepository implements PaymentHistoryRepository {
  FirebasePaymentHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<PaymentRecord>> watchHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  PaymentRecord _fromDoc(String id, Map<String, dynamic> data) {
    return PaymentRecord(
      id: id,
      type: _typeFrom(data['type'] as String?),
      packageName: data['packageName'] as String? ?? '',
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
