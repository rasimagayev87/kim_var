import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'coming_soon_screen.dart';

/// Bottom sheet shown whenever a user without an active Premium
/// subscription taps a feature gated behind Premium (e.g. a locked map
/// radius). Callers only supply the headline/body copy so the same sheet
/// can be reused for other Premium gates beyond radius.
Future<void> showPremiumUpsellSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _PremiumUpsellSheet(title: title, message: message),
  );
}

class _PremiumUpsellSheet extends StatelessWidget {
  final String title;
  final String message;

  const _PremiumUpsellSheet({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 0),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.onAccent,
                size: 34,
              ),
            ),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.sectionTitle),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(height: 1.55, fontSize: 14.5),
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComingSoonScreen(
                      title: loc.premiumComingSoonTitle,
                      icon: Icons.workspace_premium_outlined,
                      message: loc.premiumComingSoonMessage,
                    ),
                  ),
                );
              },
              child: Text(loc.premiumUpgradeButton),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: Text(loc.premiumLaterButton),
            ),
          ],
        ),
      ),
    );
  }
}
