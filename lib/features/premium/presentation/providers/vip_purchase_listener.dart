import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/vip_package.dart';

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
    onError: (Object e, StackTrace st) => logError('vip_purchase_listener', e, st),
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
  final response = await InAppPurchase.instance.queryProductDetails(kVipPackages.map((p) => p.skuId).toSet());
  return response.productDetails;
}

/// Starts the native purchase sheet for one [product] — subscriptions
/// use the same `buyNonConsumable` call as a one-time purchase in this
/// package's unified API (there's no separate "buy subscription"
/// method). The actual result arrives asynchronously on
/// [InAppPurchase.purchaseStream], handled by [_onPurchaseUpdate] —
/// this function only starts the flow, it never itself grants premium.
Future<void> buyVipPackage(ProductDetails product) {
  return InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
}

Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
  for (final purchase in purchases) {
    if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
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
        await FirebaseFunctions.instance.httpsCallable('verifyInAppPurchase').call<Map<String, dynamic>>({
          'productId': purchase.productID,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'receiptData': purchase.verificationData.serverVerificationData,
        });
      } catch (e, st) {
        logError('vip_purchase_listener.verify', e, st);
      }
    } else if (purchase.status == PurchaseStatus.error) {
      logError('vip_purchase_listener.purchaseError', purchase.error ?? 'unknown IAP error', StackTrace.current);
    }

    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }
}
