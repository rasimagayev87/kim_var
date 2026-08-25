import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:pay/pay.dart';

import '../../features/chat/presentation/theme/chat_light_theme.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'epoint_card_checkout_screen.dart';
import 'epoint_payment_result_screen.dart';
import 'epoint_token_widget_screen.dart';

/// The ONE place every Epoint-backed checkout (offer placement fee,
/// Boost, venue subscription — see `submitOffer`/`createBoostCheckout`/
/// `retryOfferPayment`/`retryVenueSubscriptionPayment`, all of which
/// return `{checkoutUrl, feeAmount, paymentId}`) opens from. Shows
/// "Kart ilə ödə" always, plus Apple Pay on iOS or Google Pay on
/// Android — never both, since a device only ever has one of them.
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

enum _Method { card, applePay }

class _EpointCheckoutSheet extends StatefulWidget {
  final String checkoutUrl;
  final String paymentId;
  final double feeAmount;

  const _EpointCheckoutSheet({required this.checkoutUrl, required this.paymentId, required this.feeAmount});

  @override
  State<_EpointCheckoutSheet> createState() => _EpointCheckoutSheetState();
}

class _EpointCheckoutSheetState extends State<_EpointCheckoutSheet> {
  _Method _selected = _Method.card;
  bool _confirming = false;

  Future<void> _payByCard() async {
    final cardResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EpointCardCheckoutScreen(checkoutUrl: widget.checkoutUrl)),
    );
    if (!mounted) return;
    Navigator.pop(context, cardResult);
  }

  Future<void> _payByApplePay() async {
    final loc = AppLocalizations.of(context);
    setState(() => _confirming = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createApplePayCheckout')
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

  Future<void> _confirm() async {
    if (_confirming) return;
    switch (_selected) {
      case _Method.card:
        await _payByCard();
      case _Method.applePay:
        await _payByApplePay();
    }
  }

  Future<void> _onGooglePayResult(Map<String, dynamic> paymentResult) async {
    final loc = AppLocalizations.of(context);
    setState(() => _confirming = true);
    try {
      final token = paymentResult['paymentMethodData']?['tokenizationData']?['token'] as String?;
      if (token == null) throw StateError('missing Google Pay token');
      await FirebaseFunctions.instance.httpsCallable('submitGooglePayToken').call<Map<String, dynamic>>({
        'paymentId': widget.paymentId,
        'googlePayToken': token,
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final amountText = widget.feeAmount.toStringAsFixed(2);

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
                icon: Icons.apple,
                iconColor: Colors.black,
                title: loc.epointApplePayOption,
                subtitle: loc.epointApplePaySubtitle,
                onTap: () => setState(() => _selected = _Method.applePay),
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
            if (Platform.isAndroid) ...[
              const SizedBox(height: 10),
              _GooglePayTile(feeAmount: widget.feeAmount, onResult: _onGooglePayResult),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.selected,
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

/// Wraps the `pay` package's own `GooglePayButton` — kept in its own
/// bordered row rather than folded into [_PaymentMethodCard]'s
/// select-then-confirm flow because, per Google's own brand
/// guidelines, it must render its OFFICIAL button (its own tap IS the
/// payment action) rather than a reskinned selectable tile.
class _GooglePayTile extends StatelessWidget {
  final double feeAmount;
  final ValueChanged<Map<String, dynamic>> onResult;

  const _GooglePayTile({required this.feeAmount, required this.onResult});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaymentConfiguration>(
      future: PaymentConfiguration.fromAsset('assets/payments/google_pay_config.json'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GooglePayButton(
            paymentConfiguration: snapshot.data!,
            paymentItems: [PaymentItem(label: 'PeakPin', amount: feeAmount.toStringAsFixed(2), status: PaymentItemStatus.final_price)],
            type: GooglePayButtonType.pay,
            width: double.infinity,
            onPaymentResult: onResult,
            loadingIndicator: const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
          ),
        );
      },
    );
  }
}
