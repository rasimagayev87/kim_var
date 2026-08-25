import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// PeakPin's own outcome screen — shown after [EpointCardCheckoutScreen]
/// sees Epoint's success/error redirect, instead of ever letting the
/// customer land on Epoint's own `success_redirect_url`/
/// `error_redirect_url` pages. [success] is a heuristic read of which
/// redirect fired, not a guarantee — `epointWebhook` is still the real
/// source of truth for whatever `payments` doc this belongs to, which
/// is why the copy here says "will be confirmed" rather than "done".
class EpointPaymentResultScreen extends StatelessWidget {
  final bool success;

  const EpointPaymentResultScreen({super.key, required this.success});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final accent = success ? AppColors.primary : AppColors.error;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
                child: Icon(success ? Icons.check_rounded : Icons.close_rounded, color: accent, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                success ? loc.epointResultSuccessTitle : loc.epointResultErrorTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1B2528)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                success ? loc.epointResultSuccessMessage : loc.epointResultErrorMessage,
                style: const TextStyle(fontSize: 14, color: Color(0xFF5B6B70), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    loc.epointResultCloseButton,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onAccent),
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
