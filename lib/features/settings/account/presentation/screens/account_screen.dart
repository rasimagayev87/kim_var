import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../profile/presentation/screens/edit_profile_screen.dart';
import '../widgets/change_email_sheet.dart';
import '../widgets/delete_account_row.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final authUser = ref.watch(authControllerProvider).valueOrNull;

    final phone = authUser?.phone;
    final email = authUser?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.accountScreenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.person_outline,
                  title: loc.accountPersonalInfoTitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.phone_outlined,
                  title: loc.accountPhoneRowTitle,
                  subtitle: phone != null
                      ? _formatPhone(phone)
                      : loc.accountPhoneUnsetValue,
                ),
                SettingsMenuRow(
                  icon: Icons.email_outlined,
                  title: loc.accountEmailRowTitle,
                  subtitle: (email == null || email.isEmpty)
                      ? loc.accountEmailEmptyValue
                      : email,
                  onTap: () => _openChangeEmail(context, email),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SettingsGroup(children: [DeleteAccountRow()]),
          ],
        ),
      ),
    );
  }

  /// "+994XXYYYZZAA" (E.164, as Firebase Auth stores it) →
  /// "+994 XX YYY ZZ AA". Numbers outside that exact shape (a different
  /// country's format) are shown as-is rather than mis-grouped.
  String _formatPhone(String raw) {
    if (!raw.startsWith('+994') || raw.length != 13) return raw;
    final rest = raw.substring(4);
    return '+994 ${rest.substring(0, 2)} ${rest.substring(2, 5)} ${rest.substring(5, 7)} ${rest.substring(7, 9)}';
  }

  Future<void> _openChangeEmail(
    BuildContext context,
    String? currentEmail,
  ) async {
    final loc = AppLocalizations.of(context);
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeEmailSheet(currentEmail: currentEmail),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.accountEmailUpdatedNotice)));
    }
  }
}
