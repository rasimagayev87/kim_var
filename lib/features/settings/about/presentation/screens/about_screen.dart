import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/animations/glow_logo.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../presentation/providers/app_version_provider.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.settingsAboutRowTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  GlowLogo(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/icon.png', width: 84, height: 84, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Meevima', style: AppTextStyles.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  SettingsPill(label: versionAsync.valueOrNull ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.auto_awesome_outlined,
                  title: loc.aboutWhatsNewTitle,
                  onTap: () => _showChangelogSheet(context, loc),
                ),
                SettingsMenuRow(
                  icon: Icons.share_outlined,
                  title: loc.aboutSocialMediaTitle,
                  trailing: SettingsPill(label: loc.aboutSocialMediaComingSoonLabel, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                loc.aboutCopyrightText,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangelogSheet(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.aboutWhatsNewTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Text(
                  loc.aboutChangelogV1Title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.white),
                ),
                const SizedBox(height: 6),
                Text(loc.aboutChangelogV1Body, style: AppTextStyles.caption.copyWith(fontSize: 13.5, height: 1.6)),
              ],
            ),
          ),
        );
      },
    );
  }
}
