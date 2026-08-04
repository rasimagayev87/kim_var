import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../privacy/presentation/providers/privacy_providers.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Updates the Firestore-stored `email` field directly — see
/// `AccountRepository.updateEmail`'s doc comment for why this is a
/// plain write rather than a Firebase-Auth email-link verification
/// (this app has no email provider linked and no transactional email
/// service configured). Pops `true` on success.
class ChangeEmailSheet extends ConsumerStatefulWidget {
  final String? currentEmail;

  const ChangeEmailSheet({super.key, this.currentEmail});

  @override
  ConsumerState<ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<ChangeEmailSheet> {
  late final _emailController = TextEditingController(text: widget.currentEmail ?? '');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.accountEmailInvalidError)));
      return;
    }

    setState(() => _saving = true);
    final success = await ref.read(accountControllerProvider).updateEmail(email);
    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.deleteAccountErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.accountChangeEmailSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
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
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                  : Text(loc.eventSaveButton),
            ),
          ],
        ),
      ),
    );
  }
}
