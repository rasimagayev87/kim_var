import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/animations/glow_logo.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vip_feature.dart';
import '../../domain/entities/vip_package.dart';
import '../providers/premium_providers.dart';
import '../providers/vip_providers.dart';
import '../providers/vip_purchase_listener.dart';

// Apple's and Google's own documented "manage subscriptions" deep
// links — not app-specific, standard for every app on each platform.
const _kAppleManageSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';
const _kGoogleManageSubscriptionsUrl = 'https://play.google.com/store/account/subscriptions';

class VipScreen extends ConsumerStatefulWidget {
  const VipScreen({super.key});

  @override
  ConsumerState<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends ConsumerState<VipScreen> {
  VipBillingPeriod _selected = VipBillingPeriod.yearly;

  bool _purchasing = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    final featuresAsync = ref.watch(vipFeaturesProvider);
    final features = (featuresAsync.valueOrNull?.isNotEmpty ?? false) ? featuresAsync.valueOrNull! : _defaultFeatures(loc);
    final products = ref.watch(vipProductsProvider).valueOrNull ?? const <ProductDetails>[];
    final selectedSku = kVipPackages.firstWhere((p) => p.period == _selected).skuId;
    ProductDetails? selectedProduct;
    for (final p in products) {
      if (p.id == selectedSku) {
        selectedProduct = p;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.settingsVipRowTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  GlowLogo(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.card),
                      alignment: Alignment.center,
                      child: const Text('👑', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(loc.vipHeaderTitle, style: AppTextStyles.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    loc.vipHeaderSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (isPremium) ...[
              _CurrentPackageCard(onManage: () => _openManageSubscription(context, loc)),
              const SizedBox(height: 20),
            ],
            for (final feature in features) _VipFeatureRow(feature: feature),
            const SizedBox(height: 24),
            Text(loc.vipChoosePackageTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PackagePill(
                    label: loc.vipPeriodMonthly,
                    selected: _selected == VipBillingPeriod.monthly,
                    onTap: () => setState(() => _selected = VipBillingPeriod.monthly),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PackagePill(
                    label: loc.vipPeriodQuarterly,
                    selected: _selected == VipBillingPeriod.quarterly,
                    onTap: () => setState(() => _selected = VipBillingPeriod.quarterly),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PackagePill(
                    label: loc.vipPeriodYearly,
                    badge: loc.vipBestValueBadge,
                    selected: _selected == VipBillingPeriod.yearly,
                    onTap: () => setState(() => _selected = VipBillingPeriod.yearly),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selectedProduct != null ? loc.vipPriceLabel(selectedProduct.price) : loc.vipPriceUnavailableNote,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF2B1D00),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (isPremium || selectedProduct == null || _purchasing)
                    ? null
                    : () => _handleSubscribe(selectedProduct!),
                child: _purchasing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF2B1D00)),
                      )
                    : Text(
                        isPremium ? loc.vipAlreadySubscribedButton : loc.vipSubscribeButton,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Only starts the native purchase sheet — [product] came from
  /// [vipProductsProvider], so it's already the store's own real
  /// listing (a valid `ProductDetails` implies the SKU genuinely
  /// exists in App Store Connect / Play Console). What happens after
  /// the customer completes payment (verification, granting
  /// `users/{uid}.premium`) is entirely `vip_purchase_listener.dart`'s
  /// job, listening on `InAppPurchase.purchaseStream` — this screen
  /// never grants premium itself, [isPremiumProvider] just reacts once
  /// the server confirms it.
  Future<void> _handleSubscribe(ProductDetails product) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    try {
      await buyVipPackage(product);
    } finally {
      // The purchase sheet itself has been dismissed either way by the
      // time this returns — `_purchasing` only needs to cover starting
      // it, not the whole async verification that follows on the
      // purchase stream (isPremiumProvider flipping is that signal).
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _openManageSubscription(BuildContext context, AppLocalizations loc) {
    final url = Theme.of(context).platform == TargetPlatform.iOS ? _kAppleManageSubscriptionsUrl : _kGoogleManageSubscriptionsUrl;
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  List<VipFeature> _defaultFeatures(AppLocalizations loc) => [
        VipFeature(icon: Icons.visibility_off_outlined, title: loc.vipFeatureGhostTitle, description: loc.vipFeatureGhostDescription),
        VipFeature(icon: Icons.radar_outlined, title: loc.vipFeatureRadiusTitle, description: loc.vipFeatureRadiusDescription),
        VipFeature(icon: Icons.tune_outlined, title: loc.vipFeatureFilterTitle, description: loc.vipFeatureFilterDescription),
        VipFeature(icon: Icons.directions_walk, title: loc.vipFeatureVisitorsTitle, description: loc.vipFeatureVisitorsDescription),
        VipFeature(icon: Icons.explore_off_outlined, title: loc.vipFeatureIncognitoTitle, description: loc.vipFeatureIncognitoDescription),
        VipFeature(icon: Icons.bolt_outlined, title: loc.vipFeaturePriorityTitle, description: loc.vipFeaturePriorityDescription),
      ];
}

class _VipFeatureRow extends StatelessWidget {
  final VipFeature feature;

  const _VipFeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(feature.icon, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.title, style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(feature.description, style: AppTextStyles.caption.copyWith(fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagePill extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PackagePill({required this.label, this.badge, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.16) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.gold : AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2B1D00))),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.gold : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPackageCard extends StatelessWidget {
  final VoidCallback onManage;

  const _CurrentPackageCard({required this.onManage});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.vipCurrentPackageTitle, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(loc.vipCurrentPackageActiveLabel, style: AppTextStyles.caption.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          TextButton(
            onPressed: onManage,
            child: Text(loc.vipManageButton, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
