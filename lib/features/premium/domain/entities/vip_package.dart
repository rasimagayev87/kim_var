enum VipBillingPeriod { monthly, quarterly, yearly }

class VipPackageOption {
  final VipBillingPeriod period;

  /// The exact product ID this package uses — must match a real
  /// auto-renewing subscription created in App Store Connect / Play
  /// Console (see this repo's own store-setup instructions) or
  /// `queryVipProducts()` (vip_purchase_listener.dart) simply won't
  /// find it, and [VipScreen] shows [AppLocalizations.
  /// vipPriceUnavailableNote] for that period instead of a price.
  final String skuId;

  const VipPackageOption({required this.period, required this.skuId});
}

/// The store subscription identifiers — monthly $1.99 / quarterly
/// $3.99 / yearly $9.99 (the actual price/currency shown to a
/// customer is whatever's configured in each store console; these
/// dollar amounts are only the target price when creating the
/// products there). Kept as named constants so pointing at a
/// different SKU later is a one-line change with no callers to touch.
const kVipPackages = [
  VipPackageOption(period: VipBillingPeriod.monthly, skuId: 'peakpin_vip_monthly'),
  VipPackageOption(period: VipBillingPeriod.quarterly, skuId: 'peakpin_vip_quarterly'),
  VipPackageOption(period: VipBillingPeriod.yearly, skuId: 'peakpin_vip_yearly'),
];
