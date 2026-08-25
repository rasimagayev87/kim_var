import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';

/// Read-only — a premium venue's "⋮" menu opens this instead of the
/// upsell sheet (see `discover_tab.dart`'s `_openVenuePremiumMenu`).
/// No extend/renew/payment action: premium is currently granted for
/// free by an admin as a seed-campaign perk, so there is nothing for
/// the owner to do here but see that it's active.
class VenuePremiumInfoScreen extends StatelessWidget {
  final DateTime? premiumSince;

  const VenuePremiumInfoScreen({super.key, this.premiumSince});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final since = premiumSince;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.venuePremiumInfoTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withValues(alpha: 0.15)),
                child: const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 38),
              ),
              const SizedBox(height: 20),
              Text(
                loc.venuePremiumInfoStatusMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                loc.venuePremiumInfoExplanationMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              if (since != null) ...[
                const SizedBox(height: 18),
                Text(
                  loc.venuePremiumInfoSinceLabel(DateFormat('d MMM y').format(since)),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
