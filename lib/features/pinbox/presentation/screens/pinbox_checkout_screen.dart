import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/pinbox.dart';
import '../providers/pinbox_providers.dart';
import 'pinbox_ticket_screen.dart';

/// PinBox Faza 7 — "Sifarişi Təsdiqlə". Order summary + pickup
/// terms/address + payment method (visual only — no real gateway, see
/// `reservePinBoxOrder`'s own doc comment in functions/src/index.ts) +
/// price breakdown + the non-cancellable notice (reused verbatim from
/// the Create form, `loc.pinboxNonRefundableNotice`) + one pay button.
class PinBoxCheckoutScreen extends ConsumerStatefulWidget {
  final PinBox pinbox;

  const PinBoxCheckoutScreen({super.key, required this.pinbox});

  @override
  ConsumerState<PinBoxCheckoutScreen> createState() => _PinBoxCheckoutScreenState();
}

class _PinBoxCheckoutScreenState extends ConsumerState<PinBoxCheckoutScreen> {
  bool _submitting = false;

  Future<void> _pay() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final loc = AppLocalizations.of(context);
    final result = await ref.read(pinboxCheckoutControllerProvider).reserveOrder(widget.pinbox.id);

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result.outcome) {
      case PinBoxReserveOutcome.success:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.pinboxOrderCreatedNotice)));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PinBoxTicketScreen(orderId: result.orderId!)),
        );
      case PinBoxReserveOutcome.soldOut:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.pinboxSoldOutErrorMessage)));
      case PinBoxReserveOutcome.error:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.pinboxCheckoutErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final pinbox = widget.pinbox;
    final pickupFormat = DateFormat('HH:mm');
    final soldOut = pinbox.isSoldOut;

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        title: Text(
          loc.pinboxCheckoutTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _SummaryCard(pinbox: pinbox),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(loc.pinboxDeliveryTermsLabel),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.card)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pickupFormat.format(pinbox.pickupWindowStart)} - ${pickupFormat.format(pinbox.pickupWindowEnd)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.pinboxPickupOnlyNotice,
                              style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pinbox.venueName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pinbox.address} · ${loc.pinboxPickupModelLabel}',
                              style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(loc.pinboxPaymentMethodLabel),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.primary, width: 1.4),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card, color: AppColors.primary),
                title: Text(
                  loc.pinboxPaymentMethodOption,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                ),
                trailing: const Icon(Icons.check_circle, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(loc.pinboxPaymentDetailsLabel),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.card)),
              child: Column(
                children: [
                  _PriceRow(label: loc.pinboxPriceLabel, value: '${pinbox.pinboxPrice.toStringAsFixed(2)} AZN'),
                  const SizedBox(height: 8),
                  _PriceRow(label: loc.pinboxServiceFeeLabel, value: loc.pinboxServiceFeeFree, valueColor: AppColors.primary),
                  const Divider(height: 22),
                  _PriceRow(
                    label: loc.pinboxTotalToPayLabel,
                    value: '${pinbox.pinboxPrice.toStringAsFixed(2)} AZN',
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.pinboxNonRefundableNotice,
                      style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_submitting || soldOut) ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  foregroundColor: ChatLightColors.contourLine,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: ChatLightColors.contourLine),
                      )
                    : Text(
                        soldOut
                            ? loc.pinboxSoldOutLabel
                            : '${loc.pinboxPayButtonLabel} · ${pinbox.pinboxPrice.toStringAsFixed(2)} AZN',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PinBox pinbox;

  const _SummaryCard({required this.pinbox});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 56,
              height: 56,
              child: pinbox.imageUrl != null
                  ? Image.network(pinbox.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: ChatLightColors.cardSurface,
                      alignment: Alignment.center,
                      child: const Icon(Icons.inventory_2_outlined, color: ChatLightColors.inkSoft, size: 26),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pinbox.venueName,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  pinbox.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${pinbox.pinboxPrice.toStringAsFixed(2)} AZN',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pinbox.originalPrice.toStringAsFixed(2)} AZN',
                      style: TextStyle(fontSize: 12.5, color: ChatLightColors.inkFaint, decoration: TextDecoration.lineThrough),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ChatLightColors.inkFaint, letterSpacing: 0.4),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _PriceRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 14.5 : 13.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: bold ? ChatLightColors.ink : ChatLightColors.inkSoft,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? ChatLightColors.ink,
          ),
        ),
      ],
    );
  }
}
