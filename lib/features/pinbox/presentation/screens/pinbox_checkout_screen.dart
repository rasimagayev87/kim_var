import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/payments/epoint_checkout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/pinbox.dart';
import '../providers/pinbox_providers.dart';
import 'pinbox_ticket_screen.dart';

/// PinBox Faza 7 — "Sifarişi Təsdiqlə". Order summary + pickup
/// terms/address + payment method + price breakdown + the
/// non-cancellable notice (reused verbatim from the Create form,
/// `loc.pinboxNonRefundableNotice`) + one pay button. "Ödə" reserves
/// the stock and opens the real Epoint checkout (Kart/Apple Pay/Google
/// Pay, via `presentEpointCheckout`) — the order only becomes a
/// redeemable ticket once `epointWebhook` confirms the charge (see
/// `reservePinBoxOrder`'s own doc comment in functions/src/index.ts).
class PinBoxCheckoutScreen extends ConsumerStatefulWidget {
  final PinBox pinbox;

  const PinBoxCheckoutScreen({super.key, required this.pinbox});

  @override
  ConsumerState<PinBoxCheckoutScreen> createState() =>
      _PinBoxCheckoutScreenState();
}

class _PinBoxCheckoutScreenState extends ConsumerState<PinBoxCheckoutScreen> {
  bool _submitting = false;
  int _quantity = 1;
  String? _quantityWarning;
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '$_quantity');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  int get _maxQuantity => widget.pinbox.stockRemaining;

  void _setQuantity(int value) {
    setState(() {
      _quantity = value;
      _quantityWarning = null;
    });
    _quantityController.text = '$value';
  }

  void _increment() {
    if (_quantity >= _maxQuantity) return;
    _setQuantity(_quantity + 1);
  }

  void _decrement() {
    if (_quantity <= 1) return;
    _setQuantity(_quantity - 1);
  }

  // Real-time clamp on direct keyboard entry — the field must never
  // display (even transiently) a value the "Ödə" button would actually
  // accept beyond stock, per this task's own explicit requirement.
  void _onQuantityChanged(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null) return;

    final loc = AppLocalizations.of(context);
    if (parsed > _maxQuantity) {
      setState(() {
        _quantity = _maxQuantity;
        _quantityWarning = loc.pinboxQuantityLimitedWarning(_maxQuantity);
      });
      _quantityController.text = '$_maxQuantity';
      _quantityController.selection = TextSelection.collapsed(
        offset: _quantityController.text.length,
      );
      return;
    }
    if (parsed < 1) {
      setState(() {
        _quantity = 1;
        _quantityWarning = null;
      });
      _quantityController.text = '1';
      _quantityController.selection = TextSelection.collapsed(
        offset: _quantityController.text.length,
      );
      return;
    }
    setState(() {
      _quantity = parsed;
      _quantityWarning = null;
    });
  }

  Future<void> _pay() async {
    if (_submitting) return;
    if (_quantity > _maxQuantity || _quantity < 1) return;
    setState(() => _submitting = true);

    final loc = AppLocalizations.of(context);
    final result = await ref
        .read(pinboxCheckoutControllerProvider)
        .reserveOrder(widget.pinbox.id, quantity: _quantity);

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result.outcome) {
      case PinBoxReserveOutcome.success:
        final checkoutUrl = result.checkoutUrl;
        final paymentId = result.paymentId;
        if (checkoutUrl != null && paymentId != null) {
          await presentEpointCheckout(
            context,
            checkoutUrl: checkoutUrl,
            paymentId: paymentId,
            feeAmount: result.feeAmount ?? 0,
          );
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PinBoxTicketScreen(orderId: result.orderId!),
          ),
        );
      case PinBoxReserveOutcome.soldOut:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.pinboxSoldOutErrorMessage)));
      case PinBoxReserveOutcome.expired:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.pinboxPickupWindowEndedErrorMessage)),
        );
      case PinBoxReserveOutcome.error:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.pinboxCheckoutErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final pinbox = widget.pinbox;
    final pickupFormat = DateFormat('HH:mm');
    final soldOut = pinbox.isSoldOut;
    // Belt-and-braces UI mirror of `reservePinBoxOrder`'s own guard — a
    // buyer who had this screen open since before the window closed
    // shouldn't see a live "Ödə" button that's guaranteed to fail.
    final windowEnded = !pinbox.pickupWindowEnd.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: ChatLightColors.ink,
          ),
        ),
        title: Text(
          loc.pinboxCheckoutTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ChatLightColors.ink,
          ),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pickupFormat.format(pinbox.pickupWindowStart)} - ${pickupFormat.format(pinbox.pickupWindowEnd)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ChatLightColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.pinboxPickupOnlyNotice,
                              style: const TextStyle(
                                fontSize: 12,
                                color: ChatLightColors.inkSoft,
                              ),
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
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pinbox.venueName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ChatLightColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pinbox.address} · ${loc.pinboxPickupModelLabel}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ChatLightColors.inkSoft,
                              ),
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
            _SectionLabel(loc.pinboxQuantityLabel),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _QuantityStepperButton(
                        icon: Icons.remove,
                        onTap: _quantity > 1 ? _decrement : null,
                      ),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: _onQuantityChanged,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ChatLightColors.ink,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      _QuantityStepperButton(
                        icon: Icons.add,
                        onTap: _quantity < _maxQuantity ? _increment : null,
                      ),
                    ],
                  ),
                  if (_quantityWarning != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _quantityWarning!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(loc.pinboxPaymentDetailsLabel),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                children: [
                  _PriceRow(
                    label: '${loc.pinboxPriceLabel} × $_quantity',
                    value: '${pinbox.pinboxPrice.toStringAsFixed(2)} AZN',
                  ),
                  const SizedBox(height: 8),
                  _PriceRow(
                    label: loc.pinboxServiceFeeLabel,
                    value: loc.pinboxServiceFeeFree,
                    valueColor: AppColors.primary,
                  ),
                  const Divider(height: 22),
                  _PriceRow(
                    label: loc.pinboxTotalToPayLabel,
                    value:
                        '${(pinbox.pinboxPrice * _quantity).toStringAsFixed(2)} AZN',
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
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The pickup window and its consequence, stated
                        // BEFORE payment and in the same weight as the
                        // rest of the screen — not as fine print.
                        //
                        // The money is not refunded if the buyer does
                        // not collect (Public Offer §5), and until now
                        // that was written nowhere the buyer could see:
                        // the notice above it only said the order could
                        // not be CANCELLED, which is a different fact.
                        // Someone who misses the window loses the
                        // amount, so they have to be told the window
                        // and the consequence together, while they can
                        // still decide not to buy.
                        Text(
                          loc.pinboxPickupWindowWarning(
                            '${pickupFormat.format(pinbox.pickupWindowStart)}–${pickupFormat.format(pinbox.pickupWindowEnd)}',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: ChatLightColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.pinboxNonRefundableNotice,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: ChatLightColors.inkSoft,
                            height: 1.4,
                          ),
                        ),
                      ],
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
                // `_quantity > _maxQuantity` is a client-side belt-and-
                // braces line only — `_onQuantityChanged`/`_increment`
                // already keep `_quantity` clamped to stock at all
                // times, so this should never actually trip in normal
                // use; `reservePinBoxOrder`'s own transaction (functions/
                // src/index.ts) is the real, unbypassable check.
                onPressed:
                    (_submitting ||
                        soldOut ||
                        windowEnded ||
                        _quantity > _maxQuantity ||
                        _quantity < 1)
                    ? null
                    : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  foregroundColor: ChatLightColors.contourLine,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: ChatLightColors.contourLine,
                        ),
                      )
                    : Text(
                        soldOut
                            ? loc.pinboxSoldOutLabel
                            : windowEnded
                            ? loc.pinboxPickupWindowEndedLabel
                            : '${loc.pinboxPayButtonLabel} · ${(pinbox.pinboxPrice * _quantity).toStringAsFixed(2)} AZN',
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 56,
              height: 56,
              child: pinbox.imageUrl != null
                  ? AppImage(
                      pinbox.imageUrl!,
                      thumbnail: true,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: ChatLightColors.cardSurface,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: ChatLightColors.inkSoft,
                        size: 26,
                      ),
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
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  pinbox.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ChatLightColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${pinbox.pinboxPrice.toStringAsFixed(2)} AZN',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pinbox.originalPrice.toStringAsFixed(2)} AZN',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ChatLightColors.inkFaint,
                        decoration: TextDecoration.lineThrough,
                      ),
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
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: ChatLightColors.inkFaint,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

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

/// Same circular `-`/`+` visual as the waitlist party-size stepper
/// (`_StepperButton`, waitlist_join_sheet.dart) — that one is file-
/// private, so this mirrors its style rather than importing it,
/// consistent with this codebase's existing per-screen-duplication
/// convention for small stepper controls.
class _QuantityStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityStepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppColors.primary.withValues(alpha: 0.12)
          : ChatLightColors.cardSurface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primary : ChatLightColors.inkFaint,
          ),
        ),
      ),
    );
  }
}
