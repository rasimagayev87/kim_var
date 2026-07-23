import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../l10n/app_localizations.dart';

/// Same support address published in the Privacy Policy / Terms of
/// Service (see `legal_texts.dart`) — kept as one literal here since
/// there's no shared constants file for legal/support contact info yet.
const String kSupportEmail = 'support@meevima.app';

void showContactUsSheet(BuildContext context) {
  final loc = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.contactUsSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(kSupportEmail, style: AppTextStyles.body.copyWith(fontSize: 15)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.textMuted),
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(text: kSupportEmail));
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text(loc.contactUsEmailCopiedNotice)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => launchUrl(Uri(scheme: 'mailto', path: kSupportEmail)),
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: Text(loc.contactUsSendEmailButton),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
