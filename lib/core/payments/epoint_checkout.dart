import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:pay/pay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/chat/presentation/theme/chat_light_theme.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
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
Future<void> presentEpointCheckout(
  BuildContext context, {
  required String checkoutUrl,
  required String paymentId,
  required double feeAmount,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => _EpointCheckoutSheet(checkoutUrl: checkoutUrl, paymentId: paymentId, feeAmount: feeAmount),
  );
}

class _EpointCheckoutSheet extends StatefulWidget {
  final String checkoutUrl;
  final String paymentId;
  final double feeAmount;

  const _EpointCheckoutSheet({required this.checkoutUrl, required this.paymentId, required this.feeAmount});

  @override
  State<_EpointCheckoutSheet> createState() => _EpointCheckoutSheetState();
}

class _EpointCheckoutSheetState extends State<_EpointCheckoutSheet> {
  bool _loading = false;

  Future<void> _payByCard() async {
    Navigator.pop(context);
    await launchUrl(Uri.parse(widget.checkoutUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _payByApplePay() async {
    final loc = AppLocalizations.of(context);
    setState(() => _loading = true);
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
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    }
  }

  Future<void> _onGooglePayResult(Map<String, dynamic> paymentResult) async {
    final loc = AppLocalizations.of(context);
    setState(() => _loading = true);
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
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.epointCheckoutErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: ChatLightColors.inkFaint.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(loc.epointCheckoutTitle, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
            const SizedBox(height: 4),
            Text(
              loc.epointCheckoutAmountLabel(widget.feeAmount.round()),
              style: const TextStyle(fontSize: 13, color: ChatLightColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
              )
            else ...[
              _CheckoutMethodTile(
                icon: Icons.credit_card_rounded,
                label: loc.epointCardOption,
                onTap: _payByCard,
              ),
              if (Platform.isIOS) ...[
                const SizedBox(height: 10),
                _CheckoutMethodTile(icon: Icons.apple, label: loc.epointApplePayOption, onTap: _payByApplePay),
              ],
              if (Platform.isAndroid) ...[
                const SizedBox(height: 10),
                _GooglePayTile(feeAmount: widget.feeAmount, onResult: _onGooglePayResult),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckoutMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CheckoutMethodTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChatLightColors.cardSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: ChatLightColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
              ),
              const Icon(Icons.chevron_right, color: ChatLightColors.inkFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the `pay` package's own `GooglePayButton` — kept in this
/// module's own tile shape so the sheet's layout stays consistent
/// between the card/Apple Pay rows (custom-drawn to match this app's
/// design system) and Google Pay (which, per Google's own brand
/// guidelines, must render its OFFICIAL button rather than a
/// reskinned one).
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
