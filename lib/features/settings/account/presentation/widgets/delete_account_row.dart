import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../onboarding/presentation/screens/welcome_screen.dart';
import '../../../../privacy/domain/repositories/account_repository.dart';
import '../../../../privacy/presentation/providers/privacy_providers.dart';
import '../../../../privacy/presentation/widgets/reauth_sheet.dart';

/// "Hesabı sil" — warning → final confirm → type-the-confirm-word →
/// (reauth if the session is stale) → the server-side `deleteAccount`
/// Cloud Function. Every step before the actual delete call is purely
/// client-side friction against an accidental tap; the Cloud Function
/// itself is the only place data actually gets deleted.
class DeleteAccountRow extends ConsumerStatefulWidget {
  const DeleteAccountRow({super.key});

  @override
  ConsumerState<DeleteAccountRow> createState() => _DeleteAccountRowState();
}

class _DeleteAccountRowState extends ConsumerState<DeleteAccountRow> {
  bool _busy = false;

  Future<bool?> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    final loc = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: AppTextStyles.cardTitle),
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(fontSize: 14.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _startFlow() async {
    final loc = AppLocalizations.of(context);

    final warned = await _confirmDialog(
      context,
      title: loc.deleteAccountWarningTitle,
      message: loc.deleteAccountWarningMessage,
      confirmLabel: loc.actionDelete,
    );
    if (warned != true || !mounted) return;

    final finalConfirm = await _confirmDialog(
      context,
      title: loc.deleteAccountFinalConfirmTitle,
      message: loc.deleteAccountFinalConfirmMessage,
      confirmLabel: loc.deleteAccountConfirmButton,
    );
    if (finalConfirm != true || !mounted) return;

    final typedConfirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _TypeToConfirmSheet(),
    );
    if (typedConfirm != true || !mounted) return;

    await _attemptDelete();
  }

  Future<void> _attemptDelete() async {
    setState(() => _busy = true);
    final loc = AppLocalizations.of(context);

    try {
      await ref.read(accountControllerProvider).deleteAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on ReauthenticationRequiredException {
      if (!mounted) return;
      setState(() => _busy = false);
      final reauthed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const ReauthSheet(),
      );
      if (reauthed == true && mounted) {
        await _attemptDelete();
      }
    } catch (e, st) {
      logError('delete_account_row', e, st);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.deleteAccountErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return SettingsMenuRow(
      icon: Icons.delete_forever_outlined,
      iconColor: AppColors.error,
      title: loc.accountDeleteRowTitle,
      subtitle: loc.accountDeleteRowSubtitle,
      titleColor: AppColors.error,
      onTap: _busy ? null : _startFlow,
      trailing: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.error,
              ),
            )
          : null,
    );
  }
}

/// The new step this task adds on top of the existing warning/final
/// confirm dialogs — "Sil" stays disabled until the typed text exactly
/// matches the localized confirm word (e.g. "SİL"/"DELETE"), so it
/// can't be dismissed with a reflexive tap the way a plain dialog button
/// can.
class _TypeToConfirmSheet extends StatefulWidget {
  const _TypeToConfirmSheet();

  @override
  State<_TypeToConfirmSheet> createState() => _TypeToConfirmSheetState();
}

class _TypeToConfirmSheetState extends State<_TypeToConfirmSheet> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final expected = loc.accountDeleteConfirmWordHint;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.deleteAccountFinalConfirmTitle,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.accountDeleteConfirmWordLabel,
              style: AppTextStyles.caption.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: AppTextStyles.body.copyWith(fontSize: 15),
              decoration: InputDecoration(hintText: expected),
              onChanged: (value) =>
                  setState(() => _matches = value.trim() == expected),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _matches ? () => Navigator.pop(context, true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(loc.deleteAccountConfirmButton),
            ),
          ],
        ),
      ),
    );
  }
}
