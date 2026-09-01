import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../providers/pinbox_providers.dart';

/// PinBox Faza 9 — venue-side redemption. Manual code entry only (no
/// camera-scan infrastructure, per the product's own Faza 0 scope
/// decision) — the cashier reads the current 6-digit code off the
/// buyer's `PinBoxTicketScreen` and types it here. Stays open after a
/// successful redemption so the cashier can process the next customer
/// without re-navigating.
class PinBoxRedeemScreen extends ConsumerStatefulWidget {
  final Venue venue;

  const PinBoxRedeemScreen({super.key, required this.venue});

  @override
  ConsumerState<PinBoxRedeemScreen> createState() => _PinBoxRedeemScreenState();
}

class _PinBoxRedeemScreenState extends ConsumerState<PinBoxRedeemScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _errorText;
  ({String pinboxTitle, int quantity})? _lastRedeemed;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (code.isEmpty || _submitting) return;

    setState(() {
      _submitting = true;
      _errorText = null;
      _lastRedeemed = null;
    });

    final result = await ref
        .read(pinboxRedeemControllerProvider)
        .redeem(venueId: widget.venue.id, code: code);
    if (!mounted) return;

    switch (result.outcome) {
      case PinBoxRedeemOutcome.success:
        setState(() {
          _submitting = false;
          _codeController.clear();
          _lastRedeemed = (
            pinboxTitle: result.pinboxTitle!,
            quantity: result.quantity!,
          );
        });
      case PinBoxRedeemOutcome.invalidCode:
        setState(() {
          _submitting = false;
          _errorText = loc.pinboxRedeemInvalidCodeMessage;
        });
      case PinBoxRedeemOutcome.error:
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.pinboxCheckoutErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
          loc.pinboxRedeemTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ChatLightColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.pinboxRedeemSubtitle,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: ChatLightColors.inkSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_lastRedeemed != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loc.pinboxRedeemSuccessMessage(
                            _lastRedeemed!.pinboxTitle,
                            _lastRedeemed!.quantity,
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ChatLightColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  border: Border.all(
                    color: _errorText != null
                        ? AppColors.error
                        : ChatLightColors.inkFaint.withValues(alpha: 0.18),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: ChatLightColors.ink,
                    letterSpacing: 6,
                  ),
                  cursorColor: AppColors.primary,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: loc.pinboxRedeemCodeHint,
                    hintStyle: TextStyle(
                      color: ChatLightColors.inkFaint,
                      fontSize: 20,
                      letterSpacing: 4,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
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
                      : Text(loc.pinboxRedeemButtonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
