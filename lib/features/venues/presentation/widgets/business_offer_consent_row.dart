import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';

/// Shown from `MyVenuesScreen`'s overdue-subscription "Ödə" button when
/// the remote `businessOfferVersion` has moved past the venue's stored
/// `offerAcceptedVersion` — unlike `checkAndShowConsentDialogIfNeeded`'s
/// dialog, this one is dismissible (cancelling just aborts the payment
/// attempt, same as backing out of the Epoint checkout would). Returns
/// `true` only if the user actually checked the box and tapped
/// "Davam et"; `false`/`null` (dismissed) means the caller must not
/// proceed with payment.
Future<bool> showBusinessOfferReacceptSheet(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const _BusinessOfferReacceptDialog(),
  );
  return result ?? false;
}

class _BusinessOfferReacceptDialog extends StatefulWidget {
  const _BusinessOfferReacceptDialog();

  @override
  State<_BusinessOfferReacceptDialog> createState() => _BusinessOfferReacceptDialogState();
}

class _BusinessOfferReacceptDialogState extends State<_BusinessOfferReacceptDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(loc.businessOfferReacceptSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BusinessOfferConsentRow(value: _accepted, onChanged: (value) => setState(() => _accepted = value)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(loc.actionCancel),
        ),
        TextButton(
          onPressed: _accepted ? () => Navigator.pop(context, true) : null,
          child: Text(loc.businessOfferReacceptContinueButton),
        ),
      ],
    );
  }
}

/// "Biznes Xidmətlərinin Publik Ofertasını oxudum və qəbul edirəm" — the
/// same controlled-checkbox-with-tappable-link shape as
/// `ConsentCheckboxRow` (`lib/features/legal/presentation/widgets/`),
/// just for the business offer's own single link instead of ToS+Privacy.
/// Used both inline in `CreateVenueScreen` (first payment) and inside
/// the re-acceptance bottom sheet shown from `MyVenuesScreen` when the
/// remote `businessOfferVersion` has moved past what a venue last
/// accepted.
class BusinessOfferConsentRow extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const BusinessOfferConsentRow({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final linkStyle = AppTextStyles.caption.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    final textStyle = AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  TextSpan(text: loc.businessOfferConsentPrefix),
                  TextSpan(
                    text: loc.legalBusinessOfferTitle,
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          launchUrl(Uri.parse(config.urlBusinessOffer), mode: LaunchMode.externalApplication),
                  ),
                  TextSpan(text: loc.businessOfferConsentSuffix),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
