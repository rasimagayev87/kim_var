import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../screens/account_verification_screen.dart';

/// The single gate every "requires a verified account" action goes
/// through. Returns true (act immediately) if already verified;
/// otherwise shows the "Hesabı təsdiq et" popup and returns false —
/// callers should simply bail out on false, exactly like a permission
/// check.
Future<bool> requireVerified(BuildContext context, WidgetRef ref) async {
  final isVerified = ref.read(profileControllerProvider).isVerified;
  if (isVerified) return true;

  final loc = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(loc.verificationRequiredTitle, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
      content: Text(loc.verificationRequiredMessage, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(loc.actionCancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountVerificationScreen()));
          },
          child: Text(loc.verificationRequiredButton),
        ),
      ],
    ),
  );
  return false;
}
