import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/venue_premium_bottom_sheet.dart';

/// A premium venue's "⋮" opens this instead of the tier-picker sheet
/// (see `discover_tab.dart`'s `_openVenuePremiumMenu`) — shows the
/// real expiry date and an "erkən yenilə" (renew early) button that
/// reopens the same checkout flow, letting the owner stack a new
/// period on top of the remaining one (see `applyPaymentOutcome`'s
/// `venue_premium` branch, functions/src/index.ts, for the
/// extend-not-overwrite logic).
class VenuePremiumInfoScreen extends ConsumerWidget {
  final String venueId;
  final DateTime? premiumSince;
  final DateTime? premiumExpiresAt;

  const VenuePremiumInfoScreen({
    super.key,
    required this.venueId,
    this.premiumSince,
    this.premiumExpiresAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final since = premiumSince;
    final expiresAt = premiumExpiresAt;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.gold,
                  size: 38,
                ),
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
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: 18),
                Text(
                  loc.venuePremiumInfoActiveUntilLabel(
                    DateFormat('d MMM y').format(expiresAt),
                  ),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (since != null) ...[
                const SizedBox(height: 6),
                Text(
                  loc.venuePremiumInfoSinceLabel(
                    DateFormat('d MMM y').format(since),
                  ),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () =>
                      openVenuePremiumCheckout(context, ref, venueId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    loc.venuePremiumRenewEarlyButton,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
