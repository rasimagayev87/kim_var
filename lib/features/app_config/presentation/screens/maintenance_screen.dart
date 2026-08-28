import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/app_config_providers.dart';

/// Shown instead of the normal app when `maintenance_mode_enabled` is
/// on. "Yenidən yoxla" re-fetches Remote Config so the screen clears
/// itself the moment the flag flips off, without forcing a full app
/// restart.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    final languageCode = ref.read(localeProvider).languageCode;
    await ref.read(appConfigProvider.notifier).refresh(languageCode);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final message = config.maintenanceMessage.isNotEmpty ? config.maintenanceMessage : loc.maintenanceDefaultMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                loc.maintenanceTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.white),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _checking ? null : _retry,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Text(
                          loc.maintenanceRetryButton,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
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
