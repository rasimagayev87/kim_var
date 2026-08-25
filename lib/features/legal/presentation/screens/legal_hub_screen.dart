import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../l10n/app_localizations.dart';

/// Served from peakpin.app (peakpin-landing's public/ dir) rather than
/// the internal kim-var-73ce9.web.app Firebase Hosting domain — that
/// domain still hosts the same files (see kim_var/legal/ +
/// firebase.json) as a mirror, but user-facing links should always
/// show the branded peakpin.app domain, not the old project id.
const String kPrivacyPolicyUrl = 'https://peakpin.app/privacy-policy.html';
const String kTermsOfServiceUrl = 'https://peakpin.app/terms-of-service.html';
const String kCommunityGuidelinesUrl = 'https://peakpin.app/community-guidelines.html';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                  icon: Icons.groups_outlined,
                  title: loc.legalCommunityGuidelinesTitle,
                  onTap: () => launchUrl(Uri.parse(kCommunityGuidelinesUrl), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
