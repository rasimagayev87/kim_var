import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/country_dial_code.dart';
import 'new_password_screen.dart';
import 'otp_verification_screen.dart';

/// "Parolu unutdum" — looks an existing account up by its linked phone
/// number, then hands off to [OtpVerificationScreen] (recovery mode)
/// and finally [NewPasswordScreen]. Pops back to its own caller with
/// `true` once the password has actually been changed.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  CountryDialCode _selectedCountry = kCountryDialCodes.first;
  bool _sendingCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finishWithResult(bool success) async {
    if (!mounted) return;
    Navigator.pop(context, success);
  }

  Future<void> _goToNewPassword() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
    );
    await _finishWithResult(done ?? false);
  }

  Future<void> _handleSendCode() async {
    final digits = _phoneController.text.trim();
    if (digits.length < 7) {
      _showError('Düzgün telefon nömrəsi daxil edin');
      return;
    }

    setState(() => _sendingCode = true);
    final fullNumber = '${_selectedCountry.dialCode}$digits';
    final controller = ref.read(authControllerProvider.notifier);

    final taken = await controller.isPhoneNumberTaken(fullNumber);
    if (!taken) {
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _showError('Bu telefon nömrəsi ilə əlaqəli hesab tapılmadı.');
      return;
    }

    await controller.startPhoneRecoveryVerification(
      phoneNumber: fullNumber,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() => _sendingCode = false);
        Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: fullNumber,
              verificationId: verificationId,
              onConfirm: (ref, verificationId, smsCode) =>
                  ref.read(authControllerProvider.notifier).confirmPhoneRecovery(
                        verificationId: verificationId,
                        smsCode: smsCode,
                      ),
              onSuccess: (ctx) async {
                final done = await Navigator.push<bool>(
                  ctx,
                  MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
                );
                if (ctx.mounted) Navigator.pop(ctx, done ?? false);
              },
            ),
          ),
        ).then((result) {
          if (result == true) _finishWithResult(true);
        });
      },
      onAutoVerified: _goToNewPassword,
      onFailed: (errorCode) {
        if (!mounted) return;
        setState(() => _sendingCode = false);
        _showError('Nömrə doğrulanmadı, yenidən cəhd edin.');
      },
    );
  }

  void _pickCountry() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.6,
            child: ListView.builder(
              itemCount: kCountryDialCodes.length,
              itemBuilder: (context, index) {
                final country = kCountryDialCodes[index];
                return ListTile(
                  leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(country.name, style: const TextStyle(color: AppColors.white, fontSize: 14.5)),
                  trailing: Text(country.dialCode, style: const TextStyle(color: AppColors.textSecondary)),
                  onTap: () {
                    setState(() => _selectedCountry = country);
                    Navigator.pop(sheetContext);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
                  ),
                  const Spacer(flex: 2),
                  const Text(
                    'Parolu unutdum',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 8),
                  const Text(
                    'Hesabınıza bağlı telefon nömrənizi daxil edin.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickCountry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                _selectedCountry.dialCode,
                                style: const TextStyle(color: AppColors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: AppColors.white, fontSize: 15),
                          decoration: const InputDecoration(hintText: '50 123 45 67'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  PremiumButton(
                    label: 'Telefon nömrəsi ilə davam et',
                    loading: _sendingCode,
                    onPressed: _handleSendCode,
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
