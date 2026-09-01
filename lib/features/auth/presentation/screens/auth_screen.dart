import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/animations/glow_logo.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../legal/presentation/widgets/consent_checkbox_row.dart';
import '../providers/auth_providers.dart';
import 'onboarding_screen.dart';
import 'verify_email_screen.dart';

const _kMinPasswordLength = 8;
const _kMaxPasswordLength = 14;
final _kSpecialCharPattern = RegExp(r'[,_.!]');

/// Sign-in/registration in one screen — email+password fields are
/// always visible (no more "tap to reveal" step), Apple/Google sit
/// below as an equally-weighted pair (Apple's own requirement that a
/// 3rd-party provider not visually outrank Sign in with Apple, now
/// satisfied by giving both the exact same outlined style rather than
/// the old stacked full-width buttons). A single "Davam et" submit
/// covers both sign-in and registration — which mode is active is
/// conveyed by the toggle link below the fields, not the button label.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _consentAccepted = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;
  String? _passwordFieldError;
  String? _confirmPasswordFieldError;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Only applied when creating a NEW password (registering) — an
  /// existing account's password predates whichever rule is current,
  /// so re-validating it on every sign-in would risk locking someone
  /// out of their own already-working account.
  bool _isPasswordStrongEnough(String password) {
    if (password.length < _kMinPasswordLength ||
        password.length > _kMaxPasswordLength)
      return false;
    final hasLetter = RegExp(r'\p{L}', unicode: true).hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasSpecial = _kSpecialCharPattern.hasMatch(password);
    return hasLetter && hasDigit && hasSpecial;
  }

  void _onPasswordChanged(String value) {
    if (_passwordFieldError != null) setState(() => _passwordFieldError = null);
    if (_isRegistering && _confirmPasswordController.text.isNotEmpty) {
      _revalidateConfirmPassword();
    }
  }

  void _onConfirmPasswordChanged(String value) => _revalidateConfirmPassword();

  void _revalidateConfirmPassword() {
    final loc = AppLocalizations.of(context);
    final confirm = _confirmPasswordController.text;
    setState(() {
      _confirmPasswordFieldError =
          confirm.isNotEmpty && confirm != _passwordController.text
          ? loc.authPasswordMismatchError
          : null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _requireConsent() {
    if (!_consentAccepted) {
      setState(
        () => _error = AppLocalizations.of(context).authConsentRequiredError,
      );
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
        MaterialPageRoute(
          builder: (_) =>
              isNewUser ? const OnboardingScreen() : const HomeScreen(),
        ),
        (route) => false,
      );
    } catch (e, st) {
      logError('auth_screen._handleResult', e, st);
      if (!mounted) return;
      // Düzəliş Prompt 10 / AUTH-12 — this app never links Apple/Google
      // credentials to an existing email/password account, so a Google
      // or Apple sign-in whose email already belongs to a DIFFERENT
      // provider (e.g. someone else previously registered that exact
      // email with a password, verified or not) throws this specific
      // FirebaseAuthException instead of just failing generically — the
      // catch-all message below used to swallow this into an
      // unexplained "sign-in failed" with no path forward. The real
      // owner of the email can still recover access via "forgot
      // password" (only they can receive that reset link), so pointing
      // them there is a genuine way out, not a dead end.
      final message =
          e is FirebaseAuthException &&
              e.code == 'account-exists-with-different-credential'
          ? AppLocalizations.of(
              context,
            ).authAccountExistsDifferentCredentialError
          : AppLocalizations.of(context).authSignInFailedError;
      setState(() {
        _submitting = false;
        _error = message;
      });
    }
  }

  Future<void> _signInWithApple() async {
    if (!_consentAccepted) return _requireConsent();
    await _handleResult(
      () => ref.read(authControllerProvider.notifier).signInWithApple(),
    );
  }

  Future<void> _signInWithGoogle() async {
    if (!_consentAccepted) return _requireConsent();
    await _handleResult(
      () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
    );
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

    setState(() {
      _passwordFieldError = null;
      _confirmPasswordFieldError = null;
    });

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = loc.authInvalidEmailError);
      return;
    }
    if (_isRegistering) {
      if (!_isPasswordStrongEnough(password)) {
        setState(() => _passwordFieldError = loc.authPasswordTooShortError);
        return;
      }
      if (password != _confirmPasswordController.text) {
        setState(
          () => _confirmPasswordFieldError = loc.authPasswordMismatchError,
        );
        return;
      }
    } else if (password.isEmpty) {
      setState(() => _passwordFieldError = loc.authPasswordTooShortError);
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
      // Gated on `isNewUser` too, not just `needsEmailVerification` alone
      // — `completeOnboarding` (Cloud Function) only ever checks
      // verification for a brand-new account (it returns early,
      // BEFORE that check, for one that's already onboarded — see its
      // own doc comment); an EXISTING account that predates this whole
      // feature and happens to still be unverified must keep signing
      // in normally, not get retroactively locked out of an app they
      // already use. Only the email+password path can land here
      // unverified at all — Google/Apple sign-in (`_handleResult`)
      // always has an already-provider-verified email. Covers both a
      // fresh registration AND a brand-new-but-not-yet-onboarded
      // account signing back in without ever having clicked the link
      // (see SplashScreen's own doc comment: a `needsOnboarding`
      // session always comes back through this exact form, never
      // straight to OnboardingScreen).
      final destination =
          isNewUser && needsEmailVerification(FirebaseAuth.instance.currentUser)
          ? VerifyEmailScreen(email: email)
          : (isNewUser ? const OnboardingScreen() : const HomeScreen());
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on FirebaseAuthException catch (e, st) {
      logError('auth_screen._submitEmailPassword', e, st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _mapAuthError(e, loc);
      });
    } on TimeoutException catch (e, st) {
      // The profile reads in `_hydrateFromFirestore` are bounded, and
      // hitting that bound is a NETWORK problem, not a credential one.
      //
      // The bound throws rather than returning null on purpose: a null
      // would read as "not onboarded" and drop an existing user into
      // the onboarding form, only to bounce them out once
      // `completeOnboarding` answered `alreadyOnboarded`. Filling in a
      // form and being thrown out of it is worse than being told to try
      // again.
      logError('auth_screen._submitEmailPassword.timeout', e, st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = loc.authConnectionSlowError;
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
      _passwordFieldError = null;
      _confirmPasswordFieldError = null;
      _confirmPasswordController.clear();
    });
  }

  Future<void> _showForgotPasswordSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _ForgotPasswordSheet(initialEmail: _emailController.text.trim()),
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
                  const SizedBox(height: 28),
                  Center(
                        child: GlowLogo(
                          child: Container(
                            width: 68,
                            height: 68,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/icon_foreground.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                      ),
                  const SizedBox(height: 20),
                  Text(
                    loc.authTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1.copyWith(fontSize: 26),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    loc.authSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: loc.authEmailHint,
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    maxLength: _isRegistering ? _kMaxPasswordLength : null,
                    onChanged: _onPasswordChanged,
                    decoration: InputDecoration(
                      hintText: loc.authPasswordHint,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      errorText: _passwordFieldError,
                      errorMaxLines: 2,
                      helperText: _isRegistering
                          ? loc.authPasswordRequirementsHint
                          : null,
                      helperMaxLines: 2,
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  if (_isRegistering) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      maxLength: _kMaxPasswordLength,
                      onChanged: _onConfirmPasswordChanged,
                      decoration: InputDecoration(
                        hintText: loc.authConfirmPasswordHint,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        errorText: _confirmPasswordFieldError,
                        counterText: '',
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _submitting ? null : _toggleMode,
                          child: Text(
                            _isRegistering
                                ? loc.authToggleToSignIn
                                : loc.authToggleToRegister,
                          ),
                        ),
                        if (!_isRegistering)
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : _showForgotPasswordSheet,
                            child: Text(loc.authForgotPasswordLink),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryButton(
                    label: loc.authContinueButton,
                    loading: _submitting,
                    onPressed: _submitEmailPassword,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          loc.authOrDivider,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          brand: _SocialBrand.apple,
                          label: loc.authContinueWithApple,
                          loading: _submitting,
                          onPressed: _signInWithApple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SocialButton(
                          brand: _SocialBrand.google,
                          label: loc.authContinueWithGoogle,
                          loading: _submitting,
                          onPressed: _signInWithGoogle,
                        ),
                      ),
                    ],
                  ),
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
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
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
      await ref
          .read(authControllerProvider.notifier)
          .sendPasswordResetEmail(email);
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
              loc.authForgotPasswordSheetTitle,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (_sent) ...[
              Text(
                loc.authForgotPasswordSentMessage(_emailController.text.trim()),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
            ] else ...[
              Text(
                loc.authForgotPasswordSheetHint,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: loc.authEmailHint,
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 18),
              _PrimaryButton(
                label: loc.authForgotPasswordSubmitButton,
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

/// The one accent-filled call-to-action per screen — plain
/// [ElevatedButton] so it picks up the app's global primary-button
/// theme (cyan fill, dark ink text) rather than redeclaring it here.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.onAccent),
              ),
            )
          : Text(label),
    );
  }
}

enum _SocialBrand { apple, google }

/// The official 4-color Google "G" mark (Google's own brand asset for
/// "Sign in with Google" buttons — https://developers.google.com/identity/branding-guidelines)
/// inlined so the button doesn't need a bundled image asset.
const _kGoogleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>
  <path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>
  <path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z"/>
  <path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>
</svg>
''';

/// Apple/Google — same size, shape, and white "on dark background"
/// chrome for both (Apple's own HIG requirement that a 3rd-party
/// provider not visually outrank Sign in with Apple), each brand's own
/// mark rendered accurately (a plain [Icons.apple] glyph for Apple —
/// already matches Apple's own black-mark guidance; the real 4-color
/// [_kGoogleLogoSvg] for Google, replacing the old generic
/// [Icons.g_mobiledata_rounded] placeholder glyph, which isn't Google's
/// actual mark).
class _SocialButton extends StatelessWidget {
  final _SocialBrand brand;
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.brand,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFF1A1A1A);
    final Widget mark = brand == _SocialBrand.apple
        ? const Icon(Icons.apple, size: 22, color: foreground)
        : SvgPicture.string(_kGoogleLogoSvg, width: 20, height: 20);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.button),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: foreground,
          side: const BorderSide(color: Color(0xFFE3E6E8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foreground),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mark,
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
