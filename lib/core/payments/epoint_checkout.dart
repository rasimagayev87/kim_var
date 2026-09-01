import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/theme/chat_light_theme.dart';
import '../../features/settings/payments/domain/entities/saved_card.dart';
import '../../features/settings/payments/presentation/providers/payment_providers.dart';
import '../../features/settings/payments/presentation/widgets/saved_card_row.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'epoint_card_checkout_screen.dart';
import 'epoint_payment_result_screen.dart';
import 'epoint_token_widget_screen.dart';

import '../../core/utils/callables.dart';

/// The ONE place every Epoint-backed checkout (offer placement fee,
/// Boost, venue subscription — see `submitOffer`/`createBoostCheckout`/
/// `retryOfferPayment`/`retryVenueSubscriptionPayment`, all of which
/// return `{checkoutUrl, feeAmount, paymentId}`) opens from. Shows
/// "Kart ilə ödə" always, plus Apple Pay on iOS or Google Pay on
/// Android — both go through Epoint's own hosted "Token Widget"
/// (`createEpointWidgetCheckout`), which serves either wallet under
/// EPOINT's own merchant accounts, so neither platform needs any
/// merchant registration on PeakPin's side — and, whenever the owner
/// has ≥1 saved card ("Kartlarım"), a "Saxlanmış kartla ödə" option
/// that charges synchronously via `payWithSavedCard`, no
/// redirect/webview step at all.
/// Whichever method the owner picks, the actual payment confirmation
/// always flows back through the SAME `epointWebhook`
/// (functions/src/index.ts) — this function only ever gets the owner
/// to Epoint's side of the transaction, it never itself marks anything
/// paid.
///
/// The card path shows [EpointPaymentResultScreen] once
/// [EpointCardCheckoutScreen] reports which redirect it saw — done
/// here, using the CALLER's own stable `context`, rather than inside
/// the (by then already-popped) bottom sheet itself.
Future<void> presentEpointCheckout(
  BuildContext context, {
  required String checkoutUrl,
  required String paymentId,
  required double feeAmount,
}) async {
  final cardResult = await showModalBottomSheet<bool?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _EpointCheckoutSheet(checkoutUrl: checkoutUrl, paymentId: paymentId, feeAmount: feeAmount),
  );
  if (cardResult == null || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => EpointPaymentResultScreen(success: cardResult)));
}

enum _Method { card, applePay, googlePay, savedCard }

class _EpointCheckoutSheet extends ConsumerStatefulWidget {
  final String checkoutUrl;
  final String paymentId;
  final double feeAmount;

  const _EpointCheckoutSheet({required this.checkoutUrl, required this.paymentId, required this.feeAmount});

  @override
  ConsumerState<_EpointCheckoutSheet> createState() => _EpointCheckoutSheetState();
}

class _EpointCheckoutSheetState extends ConsumerState<_EpointCheckoutSheet> {
  _Method _selected = _Method.card;
  bool _confirming = false;
  String? _selectedCardId;

  Future<void> _payByCard() async {
    final cardResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EpointCardCheckoutScreen(checkoutUrl: widget.checkoutUrl)),
    );
    if (!mounted) return;
    Navigator.pop(context, cardResult);
  }

  /// Apple Pay/Google Pay are immediate-action buttons, not a
  /// select-then-press-"Ödə" row like Card/Saved card — matching
  /// Apple's own HIG (their button IS the buy button, not a list
  /// selection) and shaving one tap off a flow that already needs an
  /// unavoidable extra tap on Epoint's own hosted widget page (Apple's
  /// ApplePaySession can only start from a genuine user gesture inside
  /// THAT page's own JS context — nothing on our side can skip that
  /// one, but this at least removes the one tap that WAS ours to cut).
  Future<void> _onWalletTap(_Method method) async {
    if (_confirming) return;
    setState(() => _selected = method);
    await _payByWidget();
  }

  Future<void> _payByWidget() async {
    final loc = AppLocalizations.of(context);
    setState(() => _confirming = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createEpointWidgetCheckout', options: callableOptions(kPaymentCallableTimeout))
          .call<Map<String, dynamic>>({'paymentId': widget.paymentId});
      final widgetUrl = result.data['widgetUrl'] as String;
      if (!mounted) return;
      Navigator.pop(context);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => EpointTokenWidgetScreen(widgetUrl: widgetUrl)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    }
  }

  Future<void> _paySavedCard() async {
    final cardId = _selectedCardId;
    if (cardId == null) return;
    final loc = AppLocalizations.of(context);
    setState(() => _confirming = true);
    try {
      final result = await ref
          .read(savedCardRepositoryProvider)
          .payWithCard(paymentId: widget.paymentId, cardId: cardId);
      if (!mounted) return;
      Navigator.pop(context, result.succeeded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    }
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    switch (_selected) {
      case _Method.card:
        await _payByCard();
      case _Method.applePay:
      case _Method.googlePay:
        await _payByWidget();
      case _Method.savedCard:
        await _paySavedCard();
    }
  }

  Future<void> _onSavedCardTap(List<SavedCard> cards) async {
    if (cards.length == 1) {
      setState(() {
        _selected = _Method.savedCard;
        _selectedCardId = cards.first.id;
      });
      return;
    }
    final loc = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<SavedCard>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.savedCardPickerTitle, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
                const SizedBox(height: 8),
                for (final card in cards) SavedCardRow(card: card, onTap: () => Navigator.pop(context, card)),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _selected = _Method.savedCard;
      _selectedCardId = chosen.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final amountText = widget.feeAmount.toStringAsFixed(2);
    final savedCards = ref.watch(savedCardsProvider).valueOrNull ?? const <SavedCard>[];

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
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ChatLightColors.cardSurface, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            Text(loc.epointCheckoutTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amountText,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: -0.5),
                ),
                const SizedBox(width: 6),
                const Text('AZN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ChatLightColors.ink)),
              ],
            ),
            const SizedBox(height: 20),
            _PaymentMethodCard(
              selected: _selected == _Method.card,
              icon: Icons.credit_card_rounded,
              iconColor: AppColors.primary,
              title: loc.epointCardOption,
              subtitle: loc.epointCardSubtitle,
              onTap: () => setState(() => _selected = _Method.card),
            ),
            if (Platform.isIOS)
              _PaymentMethodCard(
                selected: _selected == _Method.applePay,
                loading: _confirming && _selected == _Method.applePay,
                icon: Icons.apple,
                iconColor: Colors.black,
                title: loc.epointApplePayOption,
                subtitle: loc.epointApplePaySubtitle,
                onTap: () => _onWalletTap(_Method.applePay),
              ),
            if (Platform.isAndroid)
              _PaymentMethodCard(
                selected: _selected == _Method.googlePay,
                loading: _confirming && _selected == _Method.googlePay,
                icon: Icons.g_mobiledata_rounded,
                iconColor: Colors.black,
                title: loc.epointGooglePayOption,
                subtitle: loc.epointGooglePaySubtitle,
                onTap: () => _onWalletTap(_Method.googlePay),
              ),
            if (savedCards.isNotEmpty)
              _PaymentMethodCard(
                selected: _selected == _Method.savedCard,
                icon: Icons.credit_score_rounded,
                iconColor: AppColors.primary,
                title: loc.epointSavedCardOption,
                subtitle: loc.epointSavedCardSubtitle,
                onTap: () => _onSavedCardTap(savedCards),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: ChatLightColors.inkFaint),
                const SizedBox(width: 6),
                Text(
                  loc.epointCheckoutSecurityNote,
                  style: TextStyle(fontSize: 12, color: ChatLightColors.inkFaint, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                onPressed: _confirming ? null : _confirm,
                child: _confirming
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                      )
                    : Text(
                        loc.epointCheckoutPayButton(amountText),
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

class _PaymentMethodCard extends StatelessWidget {
  final bool selected;
  final bool loading;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.selected,
    this.loading = false,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : ChatLightColors.bg1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary : ChatLightColors.cardSurface, width: selected ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ChatLightColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft)),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? AppColors.primary : ChatLightColors.inkFaint, width: 2),
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
                child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
          ],
        ),
      ),
    );
  }
}
