import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared by `FirebaseVenueRepository.createVenue` and
/// `FirebaseOfferRepository.createOffer` — both listing types go
/// through the exact same `payments/{paymentId}` write, distinguished
/// only by [listingType]/[listingId]/[type]. Stands in for a real
/// checkout: no payment provider (Epoint/Payriff/LEOpay) is wired yet,
/// so this writes straight to `'completed'` instead of `'pending'`
/// pending a webhook confirmation. Once a provider exists, this becomes
/// "create 'pending', redirect to checkout, webhook flips it to
/// 'completed'" — the moderation/refund state machine downstream
/// (admin actions, `expireListingRevisionDeadlines`,
/// `processPaymentRefund` in functions/src/index.ts) doesn't change
/// either way, since it all keys off this doc's `status`.
Future<String> createListingPayment({
  required String ownerId,
  required String listingType,
  required String listingId,
  required String type,
  required double amount,
  String currency = 'AZN',
}) async {
  final ref = FirebaseFirestore.instance.collection('payments').doc();
  await ref.set({
    'ownerId': ownerId,
    'listingType': listingType,
    'listingId': listingId,
    'type': type,
    'amount': amount,
    'currency': currency,
    'status': 'completed',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  return ref.id;
}
