import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../privacy/domain/repositories/account_repository.dart';
import '../../../../privacy/presentation/providers/privacy_providers.dart';
import '../../../../privacy/presentation/widgets/reauth_sheet.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Sends a Firebase-Auth confirmation link to the new address (see
/// `AccountRepository.updateEmail`'s doc comment) — the real sign-in
/// email only actually changes once the user taps that link, not on
/// this screen. Pops `true` once the link has been sent successfully.
class ChangeEmailSheet extends ConsumerStatefulWidget {
  final String? currentEmail;

  const ChangeEmailSheet({super.key, this.currentEmail});

  @override
  ConsumerState<ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<ChangeEmailSheet> {
  late final _emailController = TextEditingController(
    text: widget.currentEmail ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    final loc = AppLocalizations.of(context);
    if (!_emailPattern.hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.accountEmailInvalidError)));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(accountControllerProvider).updateEmail(email);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ReauthenticationRequiredException {
      if (!mounted) return;
      setState(() => _saving = false);
      final reauthed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const ReauthSheet(),
      );
      if (reauthed == true && mounted) await _save();
    } catch (e, st) {
      logError('change_email_sheet', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.deleteAccountErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
              loc.accountChangeEmailSheetTitle,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.accountChangeEmailSheetSubtitle,
              style: AppTextStyles.caption.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: AppTextStyles.body.copyWith(fontSize: 15),
              decoration: InputDecoration(labelText: loc.accountNewEmailLabel),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Text(loc.eventSaveButton),
            ),
          ],
        ),
      ),
    );
  }
}
