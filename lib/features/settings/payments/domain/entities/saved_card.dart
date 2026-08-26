enum CardBrand { visa, mastercard, other }

/// A card registered with Epoint (`savedCards/{id}` Firestore doc,
/// via `startCardRegistration`) — never the real card number, only
/// what Epoint's webhook reports back: brand (inferred server-side
/// from the mask, Epoint doesn't return one), last 4 digits, expiry.
class SavedCard {
  final String id;
  final CardBrand brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
  });
}
