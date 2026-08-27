import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../legal/presentation/widgets/consent_checkbox_row.dart';
import '../providers/auth_providers.dart';
import 'onboarding_screen.dart';

const _kMinPasswordLength = 8;

/// Replaces the old Login/Register screen pair — sign-in is now
/// exactly 3 equally-weighted buttons (Apple's own requirement, since
/// Google is offered too: see `AuthRepository`'s doc comment), gated
/// behind the same consent checkbox the old registration screen used.
/// Apple/Google resolve immediately; E-mail expands into an inline
/// email+password form (sign-in by default, with a toggle link into
/// registration, and a "forgot password?" link) instead of navigating
/// away to a separate screen.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _consentAccepted = false;
  bool _showEmailFields = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  /// Unlike [_handleResult]'s Apple/Google path, wrong-credential
  /// errors here get ONE deliberately generic message regardless of
  /// whether the email or the password was the actual problem — see
  /// `AuthRepository.signInWithEmailPassword`'s doc comment for why
  /// (account-enumeration hygiene).
  Future<void> _submitEmailPassword() async {
    if (!_consentAccepted) return _requireConsent();
    final loc = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = loc.authInvalidEmailError);
      return;
    }
    if (password.length < _kMinPasswordLength) {
      setState(() => _error = loc.authPasswordTooShortError);
      return;
    }
    if (_isRegistering && password != _confirmPasswordController.text) {
      setState(() => _error = loc.authPasswordMismatchError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final notifier = ref.read(authControllerProvider.notifier);
      final (_, isNewUser) = _isRegistering
          ? await notifier.registerWithEmailPassword(email, password)
          : await notifier.signInWithEmailPassword(email, password);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => isNewUser ? const OnboardingScreen() : const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e, st) {
      logError('auth_screen._submitEmailPassword', e, st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _mapAuthError(e, loc);
      });
    } catch (e, st) {
      logError('auth_screen._submitEmailPassword', e, st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = loc.authSignInFailedError;
      });
    }
  }

  String _mapAuthError(FirebaseAuthException e, AppLocalizations loc) {
    switch (e.code) {
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return loc.authWrongCredentialsError;
      case 'email-already-in-use':
        return loc.authEmailAlreadyInUseError;
      case 'weak-password':
        return loc.authWeakPasswordError;
      case 'invalid-email':
        return loc.authInvalidEmailError;
      default:
        return loc.authSignInFailedError;
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _error = null;
      _confirmPasswordController.clear();
    });
  }

  Future<void> _showForgotPasswordSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ForgotPasswordSheet(initialEmail: _emailController.text.trim()),
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
                    onPressed: () => setState(() => _showEmailFields = !_showEmailFields),
                  ),
                  if (_showEmailFields) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(hintText: loc.authEmailHint),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: loc.authPasswordHint,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    if (_isRegistering) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(hintText: loc.authConfirmPasswordHint),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _submitting ? null : _toggleMode,
                          child: Text(_isRegistering ? loc.authToggleToSignIn : loc.authToggleToRegister),
                        ),
                        if (!_isRegistering)
                          TextButton(
                            onPressed: _submitting ? null : _showForgotPasswordSheet,
                            child: Text(loc.authForgotPasswordLink),
                          ),
                      ],
                    ),
                    _ProviderButton(
                      icon: Icons.arrow_forward_rounded,
                      label: _isRegistering ? loc.authRegisterButton : loc.authSignInButton,
                      dark: false,
                      loading: _submitting,
                      onPressed: _submitEmailPassword,
                    ),
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

/// Small sheet opened via "Parolu unutdum?" — a single email field
/// that calls `sendPasswordResetEmail` and swaps to a confirmation
/// message on success (mirrors `waitlist_join_sheet.dart`'s shape).
class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  final String initialEmail;

  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  ConsumerState<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  late final _emailController = TextEditingController(text: widget.initialEmail);
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = loc.authInvalidEmailError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sent = true;
      });
    } catch (e, st) {
      logError('auth_screen._ForgotPasswordSheet._submit', e, st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = loc.authSignInFailedError;
      });
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
            Text(loc.authForgotPasswordSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_sent) ...[
              Text(loc.authForgotPasswordSentMessage(_emailController.text.trim()), style: AppTextStyles.body),
              const SizedBox(height: 20),
            ] else ...[
              Text(loc.authForgotPasswordSheetHint, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: loc.authEmailHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 18),
              _ProviderButton(
                icon: Icons.send_outlined,
                label: loc.authForgotPasswordSubmitButton,
                dark: false,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ],
        ),
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
