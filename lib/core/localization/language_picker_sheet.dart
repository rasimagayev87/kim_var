import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_language.dart';
import 'locale_providers.dart';

/// The one language picker sheet, shared by every entry point that
/// offers to change the app's language (Settings → Language, and the
/// pre-login Welcome screen) — a single implementation keeps the two
/// from silently drifting apart.
void showLanguagePickerSheet(BuildContext context, WidgetRef ref) {
  final loc = AppLocalizations.of(context);
  final currentCode = ref.read(localeProvider).languageCode;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.language_outlined, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text(loc.languagePickerTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final language in kSupportedLanguages)
                ListTile(
                  title: Text(language.nativeName, style: AppTextStyles.body.copyWith(fontSize: 15.5)),
                  trailing: language.locale.languageCode == currentCode
                      ? const Icon(Icons.check_circle_outline, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocale(language.locale);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
