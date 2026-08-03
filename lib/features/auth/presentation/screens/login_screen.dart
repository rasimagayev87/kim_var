import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final needsOnboarding = await ref.read(authControllerProvider.notifier).loginWithUsername(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => needsOnboarding ? const OnboardingScreen() : const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Bu məlumatlarla hesab tapılmadı.');
    }
  }

  Future<void> _handleRegister() async {
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (registered == true && mounted) {
      _showMessage('Qeydiyyat tamamlandı, indi daxil ola bilərsiniz.');
    }
  }

  Future<void> _handleForgotPassword() async {
    final resetDone = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
    if (resetDone == true && mounted) {
      _showMessage('Parolunuz yeniləndi. İndi daxil ola bilərsiniz.');
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
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                    const Text(
                      'Daxil ol',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 28),
                    PremiumTextField(
                      controller: _usernameController,
                      label: 'İstifadəçi adı',
                      hint: 'istifadeci.adi',
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'İstifadəçi adı daxil et' : null,
                    ),
                    const SizedBox(height: 14),
                    PremiumTextField(
                      controller: _passwordController,
                      label: 'Parol',
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Parol daxil et' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        child: const Text('Parolu unutdum?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PremiumButton(
                      label: 'Daxil ol',
                      loading: _loading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: _handleRegister,
                        child: const Text('Qeydiyyatdan keç'),
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
