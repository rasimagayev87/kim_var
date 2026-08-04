import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import 'login_screen.dart';

/// A username may only contain letters, digits, `.` and `_` (3-20
/// chars) — not a product requirement by itself, but a hard technical
/// constraint: the username becomes part of a synthetic email address
/// under the hood (see `FirebaseAuthRepository._emailFor`), so it has
/// to stay email-local-part-safe.
final _usernamePattern = RegExp(r'^[a-zA-Z0-9._]{3,20}$');

enum _UsernameStatus { idle, checking, available, taken, invalidFormat }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  Timer? _debounce;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  bool _submitting = false;
  String? _passwordError;

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      setState(() => _usernameStatus = _UsernameStatus.invalidFormat);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await ref.read(authControllerProvider.notifier).isUsernameAvailable(trimmed);
      if (!mounted || _usernameController.text.trim() != trimmed) return;
      setState(() => _usernameStatus = available ? _UsernameStatus.available : _UsernameStatus.taken);
    });
  }

  Future<void> _handleRegister() async {
    final loc = AppLocalizations.of(context);
    setState(() => _passwordError = null);

    final username = _usernameController.text.trim();
    if (username.isEmpty ||
        _usernameStatus == _UsernameStatus.taken ||
        _usernameStatus == _UsernameStatus.invalidFormat ||
        _usernameStatus == _UsernameStatus.checking) {
      return;
    }

    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _passwordError = loc.registerPasswordTooShortError);
      return;
    }
    if (password != _passwordConfirmController.text) {
      setState(() => _passwordError = loc.registerPasswordMismatchError);
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(authControllerProvider.notifier).registerWithUsername(
            username: username,
            password: password,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.registerSuccessMessage)));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e, st) {
      logError('register_screen.handleRegister', e, st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _passwordError = loc.registerGenericError;
      });
    }
  }

  String? _usernameHelperText(AppLocalizations loc) {
    switch (_usernameStatus) {
      case _UsernameStatus.checking:
        return loc.registerUsernameCheckingLabel;
      case _UsernameStatus.taken:
        return loc.registerUsernameTakenError;
      case _UsernameStatus.invalidFormat:
        return loc.registerUsernameInvalidFormatError;
      case _UsernameStatus.available:
      case _UsernameStatus.idle:
        return null;
    }
  }

  Color _usernameHelperColor() {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:
      case _UsernameStatus.invalidFormat:
        return AppColors.error;
      case _UsernameStatus.checking:
      case _UsernameStatus.available:
      case _UsernameStatus.idle:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final usernameHelper = _usernameHelperText(loc);

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
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.registerTitle,
                    style: AppTextStyles.h1.copyWith(fontSize: 30),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 28),
                  PremiumTextField(
                    controller: _usernameController,
                    label: loc.registerUsernameLabel,
                    hint: loc.registerUsernameHint,
                    icon: Icons.person_outline,
                    onChanged: _onUsernameChanged,
                  ),
                  if (usernameHelper != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(usernameHelper, style: AppTextStyles.caption.copyWith(color: _usernameHelperColor())),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PremiumTextField(
                    controller: _passwordController,
                    label: loc.registerPasswordLabel,
                    hint: loc.registerPasswordHint,
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    controller: _passwordConfirmController,
                    label: loc.registerPasswordConfirmLabel,
                    hint: loc.registerPasswordConfirmHint,
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  if (_passwordError != null) ...[
                    const SizedBox(height: 12),
                    Text(_passwordError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: 28),
                  PremiumButton(
                    label: loc.registerSubmitButton,
                    loading: _submitting,
                    onPressed: _handleRegister,
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
