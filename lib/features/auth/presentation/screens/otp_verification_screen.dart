import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/auth_providers.dart';
import 'onboarding_screen.dart';

/// Second step of Firebase Phone Auth: the user enters the 6-digit
/// SMS code sent to [phoneNumber].
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = '6 rəqəmli kodu tam daxil edin');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final (_, isNewUser) = await ref.read(authControllerProvider.notifier).confirmPhoneCode(
            verificationId: widget.verificationId,
            smsCode: _codeController.text.trim(),
          );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => isNewUser ? const OnboardingScreen() : const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Kod yanlışdır və ya vaxtı bitib.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
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
                    'Kodu daxil et',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.phoneNumber} nömrəsinə göndərilən 6 rəqəmli kodu yaz.',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.white, fontSize: 24, letterSpacing: 8),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PremiumButton(
                    label: 'Təsdiqlə',
                    loading: _loading,
                    onPressed: _confirm,
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
