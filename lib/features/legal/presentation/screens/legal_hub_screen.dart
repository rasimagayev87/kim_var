import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';

class LegalHubScreen extends ConsumerWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.settingsLegalRowTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.privacy_tip_outlined,
                  title: loc.legalPrivacyPolicyTitle,
                  onTap: () => launchUrl(Uri.parse(config.urlPrivacyPolicy), mode: LaunchMode.externalApplication),
                ),
                SettingsMenuRow(
                  icon: Icons.description_outlined,
                  title: loc.legalTermsOfServiceTitle,
                  onTap: () => launchUrl(Uri.parse(config.urlTermsOfService), mode: LaunchMode.externalApplication),
                ),
                SettingsMenuRow(
                  icon: Icons.groups_outlined,
                  title: loc.legalCommunityGuidelinesTitle,
                  onTap: () =>
                      launchUrl(Uri.parse(config.urlCommunityGuidelines), mode: LaunchMode.externalApplication),
                ),
                SettingsMenuRow(
                  icon: Icons.storefront_outlined,
                  title: loc.legalBusinessOfferTitle,
                  onTap: () => launchUrl(Uri.parse(config.urlBusinessOffer), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
