import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/auth_providers.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  bool _showAccountNotFound = false;
  // Set only for errors that aren't "wrong username/password" — shown
  // instead of the account-not-found message (and its register
  // prompt, which would be misleading here) so the user can tell a
  // real credential mismatch apart from a rate-limit/network hiccup.
  String? _otherErrorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;

    setState(() {
      _submitting = true;
      _showAccountNotFound = false;
      _otherErrorMessage = null;
    });

    try {
      final (_, isNewUser) = await ref.read(authControllerProvider.notifier).loginWithUsername(
            username: username,
            password: password,
          );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => isNewUser ? const OnboardingScreen() : const HomeScreen()),
        (route) => false,
      );
    } on fb.FirebaseAuthException catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      // Wrong password / unknown username still collapse into the same
      // friendly "not found" message (deliberately not distinguished,
      // which would let a caller enumerate valid usernames) — but
      // rate-limiting and network issues are real, actionable states
      // that must not be disguised as "no such account", or a genuine
      // user with the right credentials has no way to tell them apart
      // from actually having mistyped something.
      if (e.code == 'too-many-requests') {
        setState(() {
          _submitting = false;
          _otherErrorMessage = loc.loginTooManyAttemptsError;
        });
      } else if (e.code == 'network-request-failed') {
        setState(() {
          _submitting = false;
          _otherErrorMessage = loc.loginNetworkError;
        });
      } else {
        setState(() {
          _submitting = false;
          _showAccountNotFound = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _showAccountNotFound = true;
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
                  Text(
                    loc.loginTitle,
                    style: AppTextStyles.h1.copyWith(fontSize: 30),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 32),
                  PremiumTextField(
                    controller: _usernameController,
                    label: loc.loginUsernameLabel,
                    hint: loc.loginUsernameHint,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    controller: _passwordController,
                    label: loc.loginPasswordLabel,
                    hint: loc.loginPasswordHint,
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  if (_showAccountNotFound) ...[
                    const SizedBox(height: 16),
                    Text(
                      loc.loginAccountNotFoundError,
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: Text(
                        loc.loginRegisterPromptLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (_otherErrorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _otherErrorMessage!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumButton(
                          label: loc.loginButtonLabel,
                          loading: _submitting,
                          onPressed: _handleLogin,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PremiumButton(
                          label: loc.loginRegisterButtonLabel,
                          outlined: true,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      ),
                      child: Text(loc.loginForgotPasswordLabel, style: AppTextStyles.caption),
                    ),
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
