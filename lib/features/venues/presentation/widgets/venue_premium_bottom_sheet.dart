import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/payments/epoint_checkout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../providers/venue_providers.dart';

typedef VenuePremiumCheckoutResult = ({String checkoutUrl, double feeAmount, String paymentId});

/// One "Məkanı premium et" tier — months/price pairs must match
/// `VENUE_PREMIUM_FEE_BY_MONTHS` in functions/src/index.ts exactly,
/// since the server rejects any `months` value outside that fixed
/// table.
class _VenuePremiumTier {
  final int months;
  final int priceAzn;
  final IconData icon;
  final bool isPopular;

  const _VenuePremiumTier({required this.months, required this.priceAzn, required this.icon, this.isPopular = false});
}

const _tiers = [
  _VenuePremiumTier(months: 1, priceAzn: 22, icon: Icons.workspace_premium_outlined),
  _VenuePremiumTier(months: 6, priceAzn: 99, icon: Icons.workspace_premium_rounded, isPopular: true),
  _VenuePremiumTier(months: 12, priceAzn: 199, icon: Icons.emoji_events_rounded),
];

/// Tier-picker UI for `_openVenuePremiumMenu` (discover_tab.dart) and
/// `VenuePremiumInfoScreen`'s "erkən yenilə" button — calls
/// `createVenuePremiumCheckout` itself (showing an in-button spinner
/// while it's in flight, same `_submitting` pattern as
/// `BoostOfferBottomSheet`) and pops with the
/// [VenuePremiumCheckoutResult] once Epoint has actually handed back a
/// checkout URL, or `null` if dismissed/failed. Staying open through
/// that round trip (instead of popping immediately on tap) avoids a
/// several-second gap with nothing on screen while the network call is
/// still in flight.
class VenuePremiumBottomSheet extends ConsumerStatefulWidget {
  final String venueId;

  const VenuePremiumBottomSheet({super.key, required this.venueId});

  @override
  ConsumerState<VenuePremiumBottomSheet> createState() => _VenuePremiumBottomSheetState();
}

class _VenuePremiumBottomSheetState extends ConsumerState<VenuePremiumBottomSheet> {
  int _selectedIndex = 1;
  bool _submitting = false;

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final loc = AppLocalizations.of(context);
    final months = _tiers[_selectedIndex].months;
    final result = await ref.read(venueControllerProvider).createVenuePremiumCheckout(widget.venueId, months);

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
    final hints = [loc.venuePremium1moHint, loc.venuePremium6moHint, loc.venuePremium12moHint];
    final labels = [loc.venuePremium1mo, loc.venuePremium6mo, loc.venuePremium12mo];
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
                const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 28),
                const SizedBox(width: 10),
                Text(loc.venuePremiumSheetTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ChatLightColors.ink)),
              ],
            ),
            const SizedBox(height: 6),
            Text(loc.venuePremiumSheetSubtitle, style: const TextStyle(fontSize: 14, color: ChatLightColors.inkSoft)),
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
                            Text(hints[index], style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft)),
                          ],
                        ),
                      ),
                      Text(
                        loc.venuePremiumPriceSuffix(tier.priceAzn),
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
                        loc.venuePremiumCtaButton(selected.priceAzn),
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

/// Shared open-sheet-then-checkout flow, used by both the Discover
/// "Məkanı premium et" trigger (`discover_tab.dart`) and
/// `VenuePremiumInfoScreen`'s "erkən yenilə" button — factored out so
/// neither call site duplicates the sheet-then-`presentEpointCheckout`
/// two-step.
Future<void> openVenuePremiumCheckout(BuildContext context, WidgetRef ref, String venueId) async {
  final result = await showModalBottomSheet<VenuePremiumCheckoutResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => VenuePremiumBottomSheet(venueId: venueId),
  );
  if (result == null || !context.mounted) return;
  await presentEpointCheckout(context, checkoutUrl: result.checkoutUrl, paymentId: result.paymentId, feeAmount: result.feeAmount);
}
