enum VipBillingPeriod { monthly, quarterly, yearly }

class VipPackageOption {
  final VipBillingPeriod period;

  /// The product ID this package will use once the corresponding
  /// subscription is created in Play Console / App Store Connect and
  /// wired through RevenueCat. Not a real, purchasable SKU yet — see
  /// [kSubscriptionsNotYetLive].
  final String skuId;

  const VipPackageOption({required this.period, required this.skuId});
}

/// True while there is no live billing backend: no RevenueCat API
/// keys configured and no subscription products created in Play
/// Console / App Store Connect. The VIP screen uses this to show
/// real, honest "tezliklə aktivləşəcək" messaging instead of a
/// purchase flow that can't actually charge anyone — never fake a
/// successful purchase. Flip to `false` once both are live.
const bool kSubscriptionsNotYetLive = true;

/// Configurable SKU ids — the actual identifiers to create in each
/// store console. Kept as named constants so switching them later is
/// a one-line change with no callers to touch.
const kVipPackages = [
  VipPackageOption(period: VipBillingPeriod.monthly, skuId: 'meevima_vip_monthly'),
  VipPackageOption(period: VipBillingPeriod.quarterly, skuId: 'meevima_vip_quarterly'),
  VipPackageOption(period: VipBillingPeriod.yearly, skuId: 'meevima_vip_yearly'),
];
