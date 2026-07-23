import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../l10n/app_localizations.dart';
import '../../legal_texts.dart';
import 'legal_document_screen.dart';

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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalDocumentScreen(title: loc.legalPrivacyPolicyTitle, content: kPrivacyPolicy),
                    ),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.description_outlined,
                  title: loc.legalTermsOfServiceTitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalDocumentScreen(title: loc.legalTermsOfServiceTitle, content: kTermsOfService),
                    ),
                  ),
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
