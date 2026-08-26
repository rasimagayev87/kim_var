import '../entities/saved_card.dart';

abstract class SavedCardRepository {
  /// [uid]'s active saved cards, newest first.
  Stream<List<SavedCard>> watchMyCards(String uid);

  /// Starts a card-registration attempt on Epoint's side and returns the
  /// hosted-page URL the customer enters their card on — the same
  /// `EpointCardCheckoutScreen` webview every other checkout already uses.
  /// The card only actually appears in [watchMyCards] once Epoint's
  /// webhook confirms it — this call just starts the process.
  Future<String> startCardRegistration();

  /// Stops PeakPin from listing/using this card. Epoint has no
  /// card-deregistration API, so this doesn't remove it on their side.
  Future<void> deleteCard(String cardId);

  Future<void> setDefaultCard(String cardId);

  /// Charges [cardId] for the given pending `payments/{paymentId}` doc —
  /// synchronous, no redirect/webview involved.
  Future<({bool succeeded, String? failureMessage})> payWithCard({
    required String paymentId,
    required String cardId,
  });
}
