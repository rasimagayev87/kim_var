import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';

import '../../../../core/widgets/pressable.dart';

/// "I have read and agree to the [Terms of Service] and [Privacy
/// Policy]" — a controlled checkbox (parent owns [value]) with the two
/// legal doc names as inline tappable links, opened the exact same way
/// (`url_launcher`, external browser) as the Settings → Hüquqi hub.
/// Shared between the registration screen (initial consent) and the
/// re-consent dialog (`consent_dialog.dart`) shown when the legal docs'
/// version bumps past what the signed-in user last accepted — both
/// need identical wording and behavior, just a different container.
///
/// AZ/TR attach a grammatical case suffix directly onto each link
/// ("İstifadə Şərtləri**ni**") — [AppLocalizations.consentLinkSuffix]
/// is plain (non-linked) text appended right after each link for that;
/// it's empty for EN/RU, where the sentence structure doesn't need it.
class ConsentCheckboxRow extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ConsentCheckboxRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final linkStyle = AppTextStyles.caption.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    final textStyle = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

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
          child: Pressable(
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  TextSpan(text: loc.consentPrefix),
                  TextSpan(
                    text: loc.legalTermsOfServiceTitle,
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                        Uri.parse(config.urlTermsOfService),
                        mode: LaunchMode.externalApplication,
                      ),
                  ),
                  TextSpan(text: loc.consentLinkSuffix),
                  TextSpan(text: loc.consentMiddle),
                  TextSpan(
                    text: loc.legalPrivacyPolicyTitle,
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                        Uri.parse(config.urlPrivacyPolicy),
                        mode: LaunchMode.externalApplication,
                      ),
                  ),
                  TextSpan(text: loc.consentLinkSuffix),
                  TextSpan(text: loc.consentSuffix),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
