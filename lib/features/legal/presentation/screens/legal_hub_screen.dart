import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../l10n/app_localizations.dart';

/// Hosted on Firebase Hosting (`legal/` public dir, see firebase.json) —
/// same static pages linked from app-store listings, so the in-app rows
/// and the store links always show identical content.
const String kPrivacyPolicyUrl = 'https://kim-var-73ce9.web.app/privacy-policy.html';
const String kTermsOfServiceUrl = 'https://kim-var-73ce9.web.app/terms-of-service.html';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
                  onTap: () => launchUrl(Uri.parse(kPrivacyPolicyUrl), mode: LaunchMode.externalApplication),
                ),
                SettingsMenuRow(
                  icon: Icons.description_outlined,
                  title: loc.legalTermsOfServiceTitle,
                  onTap: () => launchUrl(Uri.parse(kTermsOfServiceUrl), mode: LaunchMode.externalApplication),
                ),
                SettingsMenuRow(
                  icon: Icons.article_outlined,
                  title: loc.legalLicensesTitle,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Meevima',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
