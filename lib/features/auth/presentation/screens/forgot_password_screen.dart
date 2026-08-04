import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../widgets/phone_verification_steps.dart';
import 'login_screen.dart';

enum _Step { phoneEntry, otpEntry, newPassword }

/// "Parolu unutdum" — phone lookup, then OTP sign-in via a phone
/// credential that's already linked to some account (see
/// `FirebaseAuthRepository._signInForRecovery`), then a direct
/// password change on that now-active session. Reuses the same
/// [PhoneNumberEntryStep]/[OtpCodeEntryStep] components as account
/// verification.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _Step _step = _Step.phoneEntry;
  String? _verificationId;
  String _phoneNumber = '';
  bool _loading = false;
  String? _error;

  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submitPhone(String fullPhoneNumber) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final exists = await ref.read(authControllerProvider.notifier).isPhoneNumberTaken(fullPhoneNumber);
      if (!exists) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = loc.forgotPasswordAccountNotFoundError;
        });
        return;
      }

      _phoneNumber = fullPhoneNumber;
      await ref.read(authControllerProvider.notifier).startPhoneRecoveryVerification(
        phoneNumber: fullPhoneNumber,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _verificationId = verificationId;
            _step = _Step.otpEntry;
          });
        },
        onAutoVerified: () {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _step = _Step.newPassword;
          });
        },
        onFailed: (code) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = loc.phoneAuthVerificationFailedError;
          });
        },
      );
    } catch (e, st) {
      logError('forgot_password_screen.submitPhone', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loc.phoneAuthVerificationFailedError;
      });
    }
  }

  Future<void> _confirmCode(String code) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).confirmPhoneRecovery(
            verificationId: _verificationId!,
            smsCode: code,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _Step.newPassword;
      });
    } catch (e) {
      if (!mounted) return;
      final notRegistered = e is StateError && e.message == 'phone-not-registered';
      setState(() {
        _loading = false;
        _error = notRegistered ? loc.forgotPasswordAccountNotFoundError : loc.otpInvalidCodeError;
      });
    }
  }

  Future<void> _resend() => _submitPhone(_phoneNumber);

  Future<void> _submitNewPassword() async {
    final loc = AppLocalizations.of(context);
    setState(() => _error = null);

    final password = _newPasswordController.text;
    if (password.length < 8) {
      setState(() => _error = loc.registerPasswordTooShortError);
      return;
    }
    if (password != _newPasswordConfirmController.text) {
      setState(() => _error = loc.registerPasswordMismatchError);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).updatePassword(password);
      // Deliberate sign-out — the UI always routes back to Login,
      // matching the flow's spec, rather than leaving the caller
      // silently logged in via the recovery credential.
      await ref.read(authControllerProvider.notifier).signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.newPasswordSuccessMessage)));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loc.newPasswordGenericError;
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
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
                  ),
                  const SizedBox(height: 16),
                  if (_step == _Step.phoneEntry)
                    PhoneNumberEntryStep(
                      title: loc.forgotPasswordTitle,
                      subtitle: loc.forgotPasswordSubtitle,
                      loading: _loading,
                      errorText: _error,
                      onSubmit: _submitPhone,
                    )
                  else if (_step == _Step.otpEntry)
                    OtpCodeEntryStep(
                      phoneNumber: _phoneNumber,
                      loading: _loading,
                      errorText: _error,
                      onConfirm: _confirmCode,
                      onResend: _resend,
                    )
                  else
                    _NewPasswordStep(
                      newPasswordController: _newPasswordController,
                      confirmController: _newPasswordConfirmController,
                      loading: _loading,
                      errorText: _error,
                      onSubmit: _submitNewPassword,
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

class _NewPasswordStep extends StatelessWidget {
  final TextEditingController newPasswordController;
  final TextEditingController confirmController;
  final bool loading;
  final String? errorText;
  final VoidCallback onSubmit;

  const _NewPasswordStep({
    required this.newPasswordController,
    required this.confirmController,
    required this.loading,
    required this.onSubmit,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(loc.newPasswordTitle, style: AppTextStyles.h1.copyWith(fontSize: 30)),
        const SizedBox(height: 10),
        Text(loc.newPasswordSubtitle, style: AppTextStyles.caption),
        const SizedBox(height: 28),
        PremiumTextField(
          controller: newPasswordController,
          label: loc.newPasswordLabel,
          hint: loc.newPasswordHint,
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: 16),
        PremiumTextField(
          controller: confirmController,
          label: loc.newPasswordConfirmLabel,
          hint: loc.newPasswordConfirmHint,
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Text(errorText!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 22),
        PremiumButton(
          label: loc.newPasswordSubmitButton,
          loading: loading,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}
