import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../entities/pinbox.dart';
import '../entities/pinbox_order.dart';

/// A PinBox paired with its distance from a query's center, in metres —
/// mirrors `OfferWithDistance`. Not used until Faza 6 (Discovery),
/// declared here alongside the entity for discoverability.
typedef PinBoxWithDistance = ({PinBox pinbox, double distanceMeters});

abstract class PinBoxRepository {
  /// [venueName]/[venuePhotoUrl]/[lat]/[lng]/[address]/[country] come
  /// from the already-selected, category-eligible [Venue] (see
  /// `kPinboxEligibleVenueCategories` in venue.dart) — same
  /// never-re-fetch-the-venue-doc contract as `OfferRepository.createOffer`.
  /// No listing-fee payment here (unlike venues/offers) — PinBox has no
  /// flat creation cost, PeakPin's revenue is the per-order commission
  /// reconciled monthly (see PinBox Faza 10).
  Future<String> createPinBox({
    required String ownerId,
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required VenueCategory category,
    required String title,
    required String description,
    required File? photo,
    required double originalPrice,
    required double pinboxPrice,
    required int stockTotal,
    required DateTime pickupWindowStart,
    required DateTime pickupWindowEnd,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

  /// Owner-only edit, from Qutularım → Yaratdıqlarım's 3-dot menu —
  /// [venueId]/[venueName]/[lat]/[lng]/[address]/[country]/[category]/
  /// [stockTotal] are deliberately NOT editable here: the venue link is
  /// fixed at creation same as [createPinBox], and `stockTotal` stays
  /// out of this call because firestore.rules locks `stockRemaining`
  /// from every client update — changing one without the other would
  /// desync them, so total stock is a create-time-only decision.
  ///
  /// Returns whether the edit sent the PinBox back into moderation —
  /// the `updatePinBox` Cloud Function's own diff-based decision (see
  /// its doc comment, functions/src/index.ts). Mirrors
  /// `VenueRepository.updateVenue`/`OfferRepository.updateOffer`.
  Future<bool> updatePinBox({
    required String pinboxId,
    required String title,
    required String description,
    required double originalPrice,
    required double pinboxPrice,
    required DateTime pickupWindowStart,
    required DateTime pickupWindowEnd,
    File? photo,
    required bool hasExistingPhoto,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

  /// Owner-only delete — mirrors `OfferRepository.deleteOffer` (also
  /// removes the Storage photo, since nothing else deletes it).
  Future<void> deletePinBox(String pinboxId);

  /// Called right after a successful [updatePinBox] on an `active`
  /// PinBox — moves it back to `pending` via the `resubmitPinBox` Cloud
  /// Function (the only client path there, see firestore.rules) so an
  /// edited, already-live listing re-enters moderation instead of
  /// silently publishing whatever the owner just changed it to.
  /// Mirrors `VenueRepository.resubmitVenue`/`OfferRepository
  /// .resubmitOffer`.
  Future<void> resubmitPinBox(String pinboxId);

  Stream<PinBox?> watchPinBox(String pinboxId);

  /// Every PinBox this uid has published, regardless of status — backs
  /// the "Yaratdıqlarım" section of Qutularım (PinBox Faza 11), mirrors
  /// `OfferRepository.watchMyOffers`.
  Stream<List<PinBox>> watchMyPinBoxes(String ownerId);

  /// Every order this uid has bought, newest first, regardless of
  /// status — backs the "Aldıqlarım" section of Qutularım (PinBox Faza
  /// 11). firestore.rules only lets a `pinboxOrders` doc be read by its
  /// own `buyerId`, so this is always scoped to the signed-in user.
  Stream<List<PinBoxOrder>> watchMyOrders(String buyerId);

  /// Admin-approved ('active') boxes within [radiusKm], sorted
  /// nearest-first — mirrors `OfferRepository.fetchOffersWithinRadius`.
  /// A box with `stockRemaining == 0` is still included (see
  /// `PinBox.isSoldOut` and this collection's own doc comment on the
  /// datasource) — only [category] narrows the results, nothing filters
  /// on stock.
  Future<List<PinBoxWithDistance>> fetchPinBoxesWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    VenueCategory? category,
  });

  /// Backs "Ölkə üzrə" — mirrors `OfferRepository.fetchOffersByCountry`.
  Future<List<PinBox>> fetchPinBoxesByCountry(String country, {VenueCategory? category});

  /// Backs "Dünya üzrə" — mirrors `OfferRepository.fetchAllActiveOffers`.
  Future<List<PinBox>> fetchAllActivePinBoxes({int limit, VenueCategory? category});

  /// PinBox Faza 7 checkout — the ONLY way a `pinboxOrders` doc is ever
  /// created or `stockRemaining` ever decremented (see the
  /// `reservePinBoxOrder` Cloud Function's own doc comment: atomic
  /// stock-check-and-decrement + order creation in one transaction,
  /// never a raw client write). The order comes back `awaiting_payment`
  /// — stock is already held, but the box only becomes redeemable
  /// (`status: reserved`) once the caller completes [checkoutUrl] via
  /// `presentEpointCheckout` (lib/core/payments/epoint_checkout.dart)
  /// and `epointWebhook` confirms the charge; a declined/abandoned
  /// payment restores the held stock instead. Throws on failure (sold
  /// out / not active / not signed in) — the caller
  /// (`PinBoxController.reserveOrder`) is what turns that into a typed
  /// UI outcome, same contract as every other controller in this app.
  Future<({String orderId, String checkoutUrl, double feeAmount, String paymentId})> reservePinBoxOrder({
    required String pinboxId,
    int quantity = 1,
  });

  /// PinBox Faza 8 ticket screen — live order status/QR fields.
  Stream<PinBoxOrder?> watchPinBoxOrder(String orderId);

  /// Requests a fresh, short-lived QR token from `generatePinBoxQrToken`
  /// — see that Cloud Function's own doc comment for why this is
  /// called repeatedly (every 30s) rather than once. Returns the raw
  /// token string and its expiry; the ticket screen renders the token
  /// itself into the QR code, using the expiry only to drive its
  /// countdown/refresh timer.
  Future<({String qrToken, DateTime expiresAt})> generateQrToken(String orderId);

  /// PinBox Faza 9 — venue-side redemption. Manual code entry only (no
  /// camera scanning, see `redeemPinBoxOrder`'s own doc comment).
  /// Returns the redeemed order's short summary on success; throws on a
  /// wrong/expired code, or if [venueId] isn't owned by the caller.
  Future<({String orderId, String pinboxTitle, int quantity})> redeemPinBoxOrder({
    required String venueId,
    required String code,
  });
}
