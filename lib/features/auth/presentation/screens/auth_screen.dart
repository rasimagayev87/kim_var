import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/animations/glow_logo.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../legal/presentation/widgets/consent_checkbox_row.dart';
import '../providers/auth_providers.dart';
import 'onboarding_screen.dart';

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
    if (password.length < _kMinPasswordLength || password.length > _kMaxPasswordLength) return false;
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
          confirm.isNotEmpty && confirm != _passwordController.text ? loc.authPasswordMismatchError : null;
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
        setState(() => _confirmPasswordFieldError = loc.authPasswordMismatchError);
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
                        child: Image.asset('assets/icon_foreground.png', fit: BoxFit.contain),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
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
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
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
                      helperText: _isRegistering ? loc.authPasswordRequirementsHint : null,
                      helperMaxLines: 2,
                      counterText: '',
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
                          child: Text(_isRegistering ? loc.authToggleToSignIn : loc.authToggleToRegister),
                        ),
                        if (!_isRegistering)
                          TextButton(
                            onPressed: _submitting ? null : _showForgotPasswordSheet,
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
                    Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(loc.authOrDivider, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      ),
                      Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          icon: Icons.apple,
                          label: loc.authContinueWithApple,
                          loading: _submitting,
                          tinted: true,
                          onPressed: _signInWithApple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SocialButton(
                          icon: Icons.g_mobiledata_rounded,
                          iconSize: 28,
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
                decoration: InputDecoration(hintText: loc.authEmailHint, prefixIcon: const Icon(Icons.mail_outline_rounded)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
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

  const _PrimaryButton({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.onAccent)),
            )
          : Text(label),
    );
  }
}

/// Apple/Google — same size and shape for both (Apple's own HIG
/// requirement that a 3rd-party provider not visually outrank Sign in
/// with Apple), just [tinted] gives Apple a soft dark fill instead of
/// Google's plain outlined one — a platform-conventional distinction,
/// not a size/weight difference, so it doesn't reintroduce the outrank
/// problem.
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final double iconSize;
  final bool tinted;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.iconSize = 22,
    this.tinted = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = tinted ? Colors.white : AppColors.white;

    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: tinted ? AppColors.white : null,
        foregroundColor: foreground,
        side: tinted ? BorderSide.none : null,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: loading
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(foreground)),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize, color: foreground),
                const SizedBox(width: 8),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground))),
              ],
            ),
    );
  }
}
