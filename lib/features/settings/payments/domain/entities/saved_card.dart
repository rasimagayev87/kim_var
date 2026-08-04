enum CardBrand { visa, mastercard, other }

/// A tokenized payment method — never the real card number, only what
/// a provider (Stripe et al.) returns for display: brand, last 4
/// digits, expiry. No provider is wired up yet (see
/// `savedCardsProvider`'s doc comment), so this type currently has no
/// real data source, but the shape is real and ready for one.
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
