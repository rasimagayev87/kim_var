import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/rate_limit_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/app_user.dart' show LoginProvider;
import '../providers/privacy_providers.dart';

/// Re-authentication for the *current* user (see
/// [ReauthenticationRequiredException] doc comment), scoped to
/// whichever provider they originally signed in with — pops `true`
/// once reauthentication succeeds, so the caller knows it can retry
/// whatever threw [ReauthenticationRequiredException]. Apple/Google
/// complete synchronously (native popup); Email sends a fresh sign-in
/// link and waits on [AccountController.emailReauthCompleted], since
/// that half of the flow finishes later, out-of-band, in
/// `EmailLinkSignInScreen`. Shared by delete-account and change-email,
/// both of which can hit a stale-session error.
class ReauthSheet extends ConsumerStatefulWidget {
  const ReauthSheet({super.key});

  @override
  ConsumerState<ReauthSheet> createState() => _ReauthSheetState();
}

class _ReauthSheetState extends ConsumerState<ReauthSheet> {
  bool _busy = false;
  bool _emailLinkSent = false;
  StreamSubscription<void>? _emailReauthSub;

  @override
  void dispose() {
    _emailReauthSub?.cancel();
    super.dispose();
  }

  void _fail(Object e, StackTrace st, String site) {
    logError(site, e, st);
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    setState(() => _busy = false);
    final message = isRateLimitError(e) ? loc.authRateLimitError : loc.deleteAccountReauthFailedMessage;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _sendEmailLink() async {
    setState(() => _busy = true);
    try {
      final controller = ref.read(accountControllerProvider);
      _emailReauthSub ??= controller.emailReauthCompleted.listen((_) {
        if (!mounted) return;
        Navigator.pop(context, true);
      });
      await controller.sendReauthEmailLink();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _emailLinkSent = true;
      });
    } catch (e, st) {
      _fail(e, st, 'reauth_sheet.sendReauthEmailLink');
    }
  }

  Widget _spinner() =>
      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final provider = ref.read(accountControllerProvider).currentLoginProvider();
    final email = fb.FirebaseAuth.instance.currentUser?.email ?? '';

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
            else if (_emailLinkSent)
              Text(loc.deleteAccountReauthEmailSentMessage(email), style: AppTextStyles.body)
            else
              ElevatedButton(
                onPressed: _busy ? null : _sendEmailLink,
                child: _busy ? _spinner() : Text(loc.deleteAccountReauthEmailButton),
              ),
          ],
        ),
      ),
    );
  }
}
