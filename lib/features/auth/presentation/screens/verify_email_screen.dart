import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/animations/glow_logo.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/presentation/screens/welcome_screen.dart';
import '../providers/auth_providers.dart';
import 'onboarding_screen.dart';

/// Sits between registering with email+password and [OnboardingScreen]
/// — `completeOnboarding` (Cloud Function) now rejects an unverified
/// email+password account server-side (Google/Apple are exempt, their
/// email is already provider-verified by the sign-in itself), so this
/// screen is the normal, expected stop for that flow rather than an
/// error state. Only ever reached from [AuthScreen]'s email+password
/// path — never for Google/Apple sign-in.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _notice;
  DateTime? _lastResendAt;

  static const _resendCooldown = Duration(seconds: 30);

  Future<void> _checkVerified() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _notice = null;
    });
    final loc = AppLocalizations.of(context);
    try {
      final verified = await ref
          .read(authControllerProvider.notifier)
          .reloadAndCheckEmailVerified();
      if (!mounted) return;
      if (verified) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _checking = false;
        _notice = loc.verifyEmailNotYetVerifiedNotice;
      });
    } catch (e, st) {
      logError('verify_email_screen._checkVerified', e, st);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _notice = loc.authSignInFailedError;
      });
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    final now = DateTime.now();
    final loc = AppLocalizations.of(context);
    if (_lastResendAt != null &&
        now.difference(_lastResendAt!) < _resendCooldown) {
      setState(() => _notice = loc.verifyEmailResendCooldownNotice);
      return;
    }
    setState(() {
      _resending = true;
      _notice = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resendEmailVerification();
      _lastResendAt = now;
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = loc.verifyEmailResentNotice;
      });
    } catch (e, st) {
      logError('verify_email_screen._resend', e, st);
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = loc.authSignInFailedError;
      });
    }
  }

  Future<void> _signOutAndGoBack() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlowLogo(
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      size: 56,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.verifyEmailTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.verifyEmailBody(widget.email),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_notice != null) ...[
                    Text(
                      _notice!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: _checking ? null : _checkVerified,
                    child: _checking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.onAccent,
                              ),
                            ),
                          )
                        : Text(loc.verifyEmailContinueButton),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _resending ? null : _resend,
                    child: Text(loc.verifyEmailResendButton),
                  ),
                  TextButton(
                    onPressed: _signOutAndGoBack,
                    child: Text(loc.verifyEmailUseDifferentEmailButton),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the currently signed-in user needs to verify their email
/// before onboarding can proceed — true only for a brand-new
/// email+password account (Google/Apple emails are already
/// provider-verified, see `completeOnboarding`'s own doc comment,
/// functions/src/index.ts — mirrors that same provider check exactly,
/// same reasoning as `FirebaseAuthRepository._providerFrom`). Checked
/// right after sign-in, before routing to [OnboardingScreen] vs
/// [VerifyEmailScreen].
bool needsEmailVerification(fb.User? user) {
  if (user == null || user.emailVerified) return false;
  final isFederated = user.providerData.any(
    (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
  );
  return !isFederated;
}
