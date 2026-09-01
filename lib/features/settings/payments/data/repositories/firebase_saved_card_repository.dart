import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/saved_card.dart';
import '../../domain/repositories/saved_card_repository.dart';

import '../../../../../core/utils/callables.dart';

class FirebaseSavedCardRepository implements SavedCardRepository {
  FirebaseSavedCardRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<List<SavedCard>> watchMyCards(String uid) {
    return _firestore
        .collection('savedCards')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  SavedCard _fromDoc(String id, Map<String, dynamic> data) {
    final mask = data['cardMask'] as String? ?? '';
    final digitsOnly = mask.replaceAll(RegExp(r'\D'), '');
    return SavedCard(
      id: id,
      brand: _brandFrom(data['cardBrand'] as String?),
      last4: digitsOnly.length >= 4 ? digitsOnly.substring(digitsOnly.length - 4) : digitsOnly,
      expMonth: (data['expMonth'] as num?)?.toInt() ?? 0,
      expYear: (data['expYear'] as num?)?.toInt() ?? 0,
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  CardBrand _brandFrom(String? value) {
    return CardBrand.values.firstWhere((b) => b.name == value, orElse: () => CardBrand.other);
  }

  @override
  Future<String> startCardRegistration() async {
    final result = await _functions.httpsCallable('startCardRegistration', options: callableOptions(kPaymentCallableTimeout)).call<Map<String, dynamic>>();
    return result.data['checkoutUrl'] as String;
  }

  @override
  Future<void> deleteCard(String cardId) {
    return _functions.httpsCallable('deleteSavedCard', options: callableOptions(kPaymentCallableTimeout)).call<Map<String, dynamic>>({'cardId': cardId});
  }

  @override
  Future<void> setDefaultCard(String cardId) {
    return _functions.httpsCallable('setDefaultSavedCard', options: callableOptions(kPaymentCallableTimeout)).call<Map<String, dynamic>>({'cardId': cardId});
  }

  @override
  Future<({bool succeeded, String? failureMessage})> payWithCard({
    required String paymentId,
    required String cardId,
  }) async {
    final result = await _functions.httpsCallable('payWithSavedCard', options: callableOptions(kPaymentCallableTimeout)).call<Map<String, dynamic>>({
      'paymentId': paymentId,
      'cardId': cardId,
    });
    final data = result.data;
    return (succeeded: data['succeeded'] as bool, failureMessage: data['failureMessage'] as String?);
  }
}
