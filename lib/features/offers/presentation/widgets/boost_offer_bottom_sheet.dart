import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../providers/offer_providers.dart';

typedef BoostCheckoutResult = ({String checkoutUrl, double feeAmount, String paymentId});

/// One "Təklifi önə çək" tier — hours/price pairs must match
/// `BOOST_FEE_BY_HOURS` in functions/src/index.ts exactly, since the
/// server rejects any `hours` value outside that fixed table.
class _BoostTier {
  final int hours;
  final int priceAzn;
  final IconData icon;
  final bool isPopular;

  const _BoostTier({required this.hours, required this.priceAzn, required this.icon, this.isPopular = false});
}

const _tiers = [
  _BoostTier(hours: 6, priceAzn: 2, icon: Icons.flash_on_rounded),
  _BoostTier(hours: 12, priceAzn: 4, icon: Icons.local_fire_department_rounded, isPopular: true),
  _BoostTier(hours: 18, priceAzn: 6, icon: Icons.workspace_premium_rounded),
];

/// Tier-picker UI for `_HeroImage._openBoostMenu` (offer_details_screen.dart)
/// — calls `createBoostCheckout` itself (showing an in-button spinner
/// while it's in flight, same `_submitting` pattern as
/// `create_venue_screen.dart`/`pinbox_checkout_screen.dart`) and pops
/// with the [BoostCheckoutResult] once Epoint has actually handed back
/// a checkout URL, or `null` if dismissed/failed. Staying open through
/// that round trip (instead of popping immediately on tap) is
/// deliberate — popping first left a several-second gap with nothing
/// on screen while the network call was still in flight.
class BoostOfferBottomSheet extends ConsumerStatefulWidget {
  final String offerId;

  const BoostOfferBottomSheet({super.key, required this.offerId});

  @override
  ConsumerState<BoostOfferBottomSheet> createState() => _BoostOfferBottomSheetState();
}

class _BoostOfferBottomSheetState extends ConsumerState<BoostOfferBottomSheet> {
  int _selectedIndex = 1;
  bool _submitting = false;

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final loc = AppLocalizations.of(context);
    final hours = _tiers[_selectedIndex].hours;
    final result = await ref.read(offerControllerProvider).createBoostCheckout(widget.offerId, hours);

    if (!mounted) return;
    if (result == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerGenericErrorMessage)));
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final multipliers = [loc.offerBoostMultiplier6h, loc.offerBoostMultiplier12h, loc.offerBoostMultiplier18h];
    final labels = [loc.offerBoost6h, loc.offerBoost12h, loc.offerBoost18h];
    final selected = _tiers[_selectedIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: ChatLightColors.cardSurface, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Text(loc.offerBoostMenuItem, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ChatLightColors.ink)),
              ],
            ),
            const SizedBox(height: 6),
            Text(loc.offerBoostSheetSubtitle, style: const TextStyle(fontSize: 14, color: ChatLightColors.inkSoft)),
            const SizedBox(height: 20),
            ...List.generate(_tiers.length, (index) {
              final tier = _tiers[index];
              final isSelected = _selectedIndex == index;

              return GestureDetector(
                onTap: _submitting ? null : () => setState(() => _selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : ChatLightColors.bg1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppColors.primary : ChatLightColors.cardSurface, width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : ChatLightColors.cardSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(tier.icon, color: isSelected ? AppColors.onAccent : ChatLightColors.inkSoft, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(labels[index], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ChatLightColors.ink)),
                                if (tier.isPopular) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFFFE9C7), borderRadius: BorderRadius.circular(20)),
                                    child: Text(
                                      loc.offerBoostMostPopularBadge,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8A5A00)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(multipliers[index], style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft)),
                          ],
                        ),
                      ),
                      Text(
                        loc.offerBoostPriceSuffix(tier.priceAzn),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onAccent,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submitting ? null : _confirm,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                      )
                    : Text(
                        loc.offerBoostCtaButton(selected.priceAzn),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onAccent),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
