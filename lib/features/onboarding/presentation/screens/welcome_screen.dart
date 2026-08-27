import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/animations/glow_logo.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/language_picker_sheet.dart';
import '../../../../core/localization/locale_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/screens/auth_screen.dart';

/// Language can be picked here too (not just later in Settings) —
/// since it changes the shared [localeProvider], picking it here
/// re-localizes AuthScreen and the rest of the app immediately, before
/// the user has even signed in.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final currentLanguage = kSupportedLanguages.firstWhere(
      (language) => language.locale.languageCode == ref.watch(localeProvider).languageCode,
      orElse: () => kSupportedLanguages.first,
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: Material(
                  color: AppColors.card,
                  shape: const StadiumBorder(side: BorderSide(color: AppColors.divider)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => showLanguagePickerSheet(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_outlined, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            currentLanguage.locale.languageCode.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  GlowLogo(
                    child: Image.asset(
                      'assets/icon_foreground.png',
                      width: 220,
                      height: 220,
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                      ),
                  const SizedBox(height: 22),
                  Text(
                    loc.welcomeHeadline,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionTitle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                  const SizedBox(height: 8),
                  Text(
                    loc.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                  ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                  const Spacer(flex: 4),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    ),
                    child: Text(loc.welcomeStartButton),
                  ).animate().fadeIn(delay: 450.ms, duration: 450.ms).slideY(
                        begin: 0.2,
                        end: 0,
                      ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
