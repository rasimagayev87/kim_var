import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../core/navigation/deep_link_handler.dart' show navigatorKey;
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vip_package.dart';

import '../../../../core/utils/callables.dart';

/// Started once from `main.dart`, same pattern/reasoning as
/// `startDeepLinkListener` — a subscription's own doc comment on
/// `InAppPurchase.purchaseStream` says to listen "as early as possible"
/// so a purchase that completes while the app is backgrounded, or one
/// still pending from a previous session, isn't missed. Never
/// cancelled: this needs to outlive every screen, including
/// [VipScreen] itself, for the app's whole lifetime.
StreamSubscription<List<PurchaseDetails>>? _subscription;

void startVipPurchaseListener() {
  _subscription ??= InAppPurchase.instance.purchaseStream.listen(
    _onPurchaseUpdate,
    onError: (Object e, StackTrace st) =>
        logError('vip_purchase_listener', e, st),
  );
}

/// Live store-priced product details for [kVipPackages] — [VipScreen]
/// shows real, store-localized prices from this rather than a
/// hardcoded currency string, since the actual price/currency a
/// customer sees is set in App Store Connect / Play Console, not in
/// this app. Empty if the store is unreachable or none of the
/// [kVipPackages] SKUs exist there yet (see this app's own store-setup
/// instructions — a fresh subscription product can take a few hours to
/// propagate after creation).
Future<List<ProductDetails>> queryVipProducts() async {
  if (!await InAppPurchase.instance.isAvailable()) return const [];
  final response = await InAppPurchase.instance.queryProductDetails(
    kVipPackages.map((p) => p.skuId).toSet(),
  );
  return response.productDetails;
}

/// Starts the native purchase sheet for one [product] — subscriptions
/// use the same `buyNonConsumable` call as a one-time purchase in this
/// package's unified API (there's no separate "buy subscription"
/// method). The actual result arrives asynchronously on
/// [InAppPurchase.purchaseStream], handled by [_onPurchaseUpdate] —
/// this function only starts the flow, it never itself grants premium.
Future<void> buyVipPackage(ProductDetails product) {
  return InAppPurchase.instance.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );
}

/// Apple requires a working "Restore Purchases" control for any app
/// selling non-consumable/subscription IAP (App Review rejects its
/// absence) — a customer who reinstalls, or bought VIP on another of
/// their own devices, has no other way back to it since this app never
/// asks for a password/receipt manually. On iOS this actively re-queries
/// StoreKit for past purchases; on Android, Play Billing already
/// surfaces the customer's active purchases without a separate restore
/// call, but `restorePurchases()` is safe/near-instant there regardless
/// (see the `in_app_purchase` package's own doc comment), so this is
/// called unconditionally rather than gating it on platform. Results
/// arrive on the SAME [purchaseStream] as a fresh purchase
/// (`PurchaseStatus.restored`, handled identically by
/// [_onPurchaseUpdate]) — this function itself never grants premium.
Future<void> restoreVipPurchases() {
  return InAppPurchase.instance.restorePurchases();
}

Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
  for (final purchase in purchases) {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      try {
        // `verifyInAppPurchase` (Cloud Function, functions/src/index.ts)
        // is the only thing that ever sets `users/{uid}.premium` from a
        // real purchase — this call never assumes success locally, the
        // Firestore-backed `isPremiumProvider` only flips once the
        // server has actually validated the receipt/token with Apple/
        // Google. A failure here just means premium doesn't unlock;
        // `completePurchase` below still runs regardless so the store
        // doesn't treat this as a stuck transaction — the purchase
        // itself already succeeded from the store's point of view, this
        // app failing to verify it is this app's problem, not grounds
        // to leave the customer's transaction hanging.
        await FirebaseFunctions.instance
            .httpsCallable('verifyInAppPurchase', options: callableOptions())
            .call<Map<String, dynamic>>({
              'productId': purchase.productID,
              'platform': Platform.isIOS ? 'ios' : 'android',
              'receiptData': purchase.verificationData.serverVerificationData,
            });
      } catch (e, st) {
        logError('vip_purchase_listener.verify', e, st);
        // Düzəliş Prompt 7 — a rejected verification (PAY-25's
        // owned-by-another-account check, H #196's sandbox check, a
        // revoked/mismatched transaction) used to fail completely
        // silently from the customer's point of view — the purchase
        // sheet closes, nothing ever unlocks, no explanation. Surfaced
        // via the app's global [navigatorKey] (same "no BuildContext at
        // the call site" shape as `ensureWritableOrWarn`,
        // read_only_guard.dart) since this listener runs outside any
        // screen's widget tree.
        _showVerificationError(e);
      }
    } else if (purchase.status == PurchaseStatus.error) {
      logError(
        'vip_purchase_listener.purchaseError',
        purchase.error ?? 'unknown IAP error',
        StackTrace.current,
      );
    }

    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }
}

void _showVerificationError(Object error) {
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  final loc = AppLocalizations.of(context);
  // `verifyInAppPurchase`'s own HttpsError messages are already
  // full Azerbaijani sentences meant for display (see its doc
  // comment in functions/src/index.ts) — shown as-is rather than
  // re-mapped client-side, so server and client never drift out of
  // sync on wording. Anything else (network failure, etc.) falls
  // back to a generic message.
  final message =
      error is FirebaseFunctionsException &&
          error.message != null &&
          error.message!.isNotEmpty
      ? error.message!
      : loc.vipVerificationErrorGeneric;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
