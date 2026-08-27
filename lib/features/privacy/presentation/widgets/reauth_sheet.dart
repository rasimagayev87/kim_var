import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/app_user.dart' show LoginProvider;
import '../providers/privacy_providers.dart';

/// Re-authentication for the *current* user (see
/// [ReauthenticationRequiredException] doc comment), scoped to
/// whichever provider they originally signed in with — pops `true`
/// once reauthentication succeeds, so the caller knows it can retry
/// whatever threw [ReauthenticationRequiredException]. All 3 providers
/// (Apple/Google native popup, Email a password field) complete
/// synchronously now. Shared by delete-account and change-email, both
/// of which can hit a stale-session error.
class ReauthSheet extends ConsumerStatefulWidget {
  const ReauthSheet({super.key});

  @override
  ConsumerState<ReauthSheet> createState() => _ReauthSheetState();
}

class _ReauthSheetState extends ConsumerState<ReauthSheet> {
  bool _busy = false;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _fail(Object e, StackTrace st, String site) {
    logError(site, e, st);
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.deleteAccountReauthFailedMessage)));
  }

  Future<void> _reauthApple() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountControllerProvider).reauthenticateWithApple();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      _fail(e, st, 'reauth_sheet.reauthApple');
    }
  }

  Future<void> _reauthGoogle() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountControllerProvider).reauthenticateWithGoogle();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      _fail(e, st, 'reauth_sheet.reauthGoogle');
    }
  }

  Future<void> _reauthPassword() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountControllerProvider).reauthenticateWithPassword(_passwordController.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      _fail(e, st, 'reauth_sheet.reauthPassword');
    }
  }

  Widget _spinner() =>
      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final provider = ref.read(accountControllerProvider).currentLoginProvider();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.deleteAccountReauthTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(loc.deleteAccountReauthMessage, style: AppTextStyles.caption.copyWith(height: 1.4)),
            const SizedBox(height: 16),
            if (provider == LoginProvider.apple)
              ElevatedButton(
                onPressed: _busy ? null : _reauthApple,
                child: _busy ? _spinner() : Text(loc.deleteAccountReauthAppleButton),
              )
            else if (provider == LoginProvider.google)
              ElevatedButton(
                onPressed: _busy ? null : _reauthGoogle,
                child: _busy ? _spinner() : Text(loc.deleteAccountReauthGoogleButton),
              )
            else ...[
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(hintText: loc.authPasswordHint),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _busy ? null : _reauthPassword,
                child: _busy ? _spinner() : Text(loc.deleteAccountReauthEmailButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
