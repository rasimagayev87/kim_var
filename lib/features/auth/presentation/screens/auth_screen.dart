import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/rate_limit_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../legal/presentation/widgets/consent_checkbox_row.dart';
import '../providers/auth_providers.dart';
import 'onboarding_screen.dart';

/// Replaces the old Login/Register screen pair — sign-in is now
/// exactly 3 equally-weighted buttons (Apple's own requirement, since
/// Google is offered too: see `AuthRepository`'s doc comment), gated
/// behind the same consent checkbox the old registration screen used.
/// Apple/Google resolve immediately; E-mail expands an inline field
/// and sends a passwordless sign-in link instead of navigating away.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _consentAccepted = false;
  bool _showEmailField = false;
  bool _emailLinkSent = false;
  bool _submitting = false;
  String? _error;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _requireConsent() {
    if (!_consentAccepted) {
      setState(() => _error = AppLocalizations.of(context).authConsentRequiredError);
    }
  }

  Future<void> _handleResult(Future<(dynamic, bool)> Function() signIn) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final (_, isNewUser) = await signIn();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => isNewUser ? const OnboardingScreen() : const HomeScreen()),
        (route) => false,
      );
    } catch (e, st) {
      logError('auth_screen._handleResult', e, st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = AppLocalizations.of(context).authSignInFailedError;
      });
    }
  }

  Future<void> _signInWithApple() async {
    if (!_consentAccepted) return _requireConsent();
    await _handleResult(() => ref.read(authControllerProvider.notifier).signInWithApple());
  }

  Future<void> _signInWithGoogle() async {
    if (!_consentAccepted) return _requireConsent();
    await _handleResult(() => ref.read(authControllerProvider.notifier).signInWithGoogle());
  }

  Future<void> _sendEmailLink() async {
    if (!_consentAccepted) return _requireConsent();
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = AppLocalizations.of(context).authInvalidEmailError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendEmailSignInLink(email);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _emailLinkSent = true;
      });
    } catch (e, st) {
      // Unlike _handleResult's Apple/Google path, this one had no
      // logging at all — a real failure here (e.g. a FirebaseAuthException
      // whose code isn't the rate-limit one) was previously
      // indistinguishable from any other cause behind the generic
      // authSignInFailedError text, with nothing in Crashlytics/console
      // to diagnose it from afterward.
      logError('auth_screen._sendEmailLink', e, st);
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      setState(() {
        _submitting = false;
        _error = isRateLimitError(e) ? loc.authRateLimitError : loc.authSignInFailedError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Text(loc.authTitle, style: AppTextStyles.h1.copyWith(fontSize: 30)).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(loc.authSubtitle, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 36),
                  if (_emailLinkSent) ...[
                    Text(
                      loc.authEmailLinkSentMessage(_emailController.text.trim()),
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.authEmailLinkSpamHint,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ] else ...[
                    _ProviderButton(
                      icon: Icons.apple,
                      label: loc.authContinueWithApple,
                      dark: true,
                      loading: _submitting,
                      onPressed: _signInWithApple,
                    ),
                    const SizedBox(height: 14),
                    _ProviderButton(
                      icon: Icons.g_mobiledata_rounded,
                      label: loc.authContinueWithGoogle,
                      dark: false,
                      loading: _submitting,
                      onPressed: _signInWithGoogle,
                    ),
                    const SizedBox(height: 14),
                    _ProviderButton(
                      icon: Icons.email_outlined,
                      label: loc.authContinueWithEmail,
                      dark: false,
                      loading: _submitting,
                      onPressed: () => setState(() => _showEmailField = !_showEmailField),
                    ),
                    if (_showEmailField) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(hintText: loc.authEmailHint),
                      ),
                      const SizedBox(height: 10),
                      _ProviderButton(
                        icon: Icons.send_outlined,
                        label: loc.authSendLinkButton,
                        dark: false,
                        loading: _submitting,
                        onPressed: _sendEmailLink,
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: 24),
                  ConsentCheckboxRow(
                    value: _consentAccepted,
                    onChanged: (v) => setState(() {
                      _consentAccepted = v;
                      if (v) _error = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the 3 sign-in options — same envelope for all 3 (Apple's own
/// requirement that a 3rd-party provider button not visually outrank
/// Sign in with Apple), just [dark] flips fill vs outline to match
/// each provider's own conventional treatment.
class _ProviderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;
  final bool loading;
  final VoidCallback onPressed;

  const _ProviderButton({
    required this.icon,
    required this.label,
    required this.dark,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // AppColors.white/.onAccent are the SAME dark navy (a light-theme
    // app despite the name) — using either for both would make the
    // Apple button's text invisible against its own background, so
    // this one spot reaches past the design tokens for a real black
    // button + real white text, matching Apple's own HIG button style.
    final foreground = dark ? Colors.white : AppColors.white;
    final background = dark ? Colors.black : AppColors.card;

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: dark ? null : const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(foreground)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 10),
                  Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
