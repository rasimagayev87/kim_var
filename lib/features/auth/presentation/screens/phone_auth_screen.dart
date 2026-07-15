import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/auth_providers.dart';
import '../widgets/country_dial_code.dart';
import 'onboarding_screen.dart';
import 'otp_verification_screen.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  CountryDialCode _selectedCountry = kCountryDialCodes.first; // Azerbaijan default
  bool _sendingCode = false;
  bool _googleLoading = false;
  bool _appleLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _goToDestination(BuildContext context, bool isNewUser) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => isNewUser ? const OnboardingScreen() : const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _handleSendCode() async {
    final digits = _phoneController.text.trim();
    if (digits.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Düzgün telefon nömrəsi daxil edin')),
      );
      return;
    }

    setState(() => _sendingCode = true);
    final fullNumber = '${_selectedCountry.dialCode}$digits';

    await ref.read(authControllerProvider.notifier).startPhoneVerification(
      phoneNumber: fullNumber,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() => _sendingCode = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: fullNumber,
              verificationId: verificationId,
            ),
          ),
        );
      },
      onAutoVerified: (user, isNewUser) {
        if (!mounted) return;
        setState(() => _sendingCode = false);
        _goToDestination(context, isNewUser);
      },
      onFailed: (message) {
        if (!mounted) return;
        setState(() => _sendingCode = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final (_, isNewUser) = await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      _goToDestination(context, isNewUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google girişi uğursuz oldu: $e')),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _handleApple() async {
    setState(() => _appleLoading = true);
    try {
      final (_, isNewUser) = await ref.read(authControllerProvider.notifier).signInWithApple();
      if (!mounted) return;
      _goToDestination(context, isNewUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple girişi uğursuz oldu: $e')),
      );
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
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
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Ölkə seç',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
                Expanded(
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
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xəta baş verdi: $error')),
          );
        },
      );
    });

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
                    'Telefon nömrən',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 8),
                  const Text(
                    'SMS ilə göndəriləcək koda ehtiyacın olacaq.',
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
                          decoration: const InputDecoration(
                            hintText: '50 123 45 67',
                          ),
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
                  const SizedBox(height: 28),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('və ya', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (Platform.isIOS)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PremiumButton(
                        label: 'Apple ilə davam et',
                        outlined: true,
                        loading: _appleLoading,
                        onPressed: _handleApple,
                      ),
                    ),
                  PremiumButton(
                    label: 'Google ilə davam et',
                    outlined: true,
                    loading: _googleLoading,
                    onPressed: _handleGoogle,
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
