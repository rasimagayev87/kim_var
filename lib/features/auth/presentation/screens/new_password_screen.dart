import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../providers/auth_providers.dart';

/// Last step of "Parolu unutdum": the phone-recovery sign-in has
/// already happened by the time this screen is reached, so this only
/// sets the new password, then signs out again — the user comes back
/// in through [LoginScreen] with their new credentials, same as right
/// after registering.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      _showMessage('Parollar uyğun gəlmir.');
      return;
    }

    setState(() => _saving = true);
    final controller = ref.read(authControllerProvider.notifier);
    try {
      await controller.updatePassword(_passwordController.text);
      await controller.signOut();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Parol yenilənmədi. Bir az sonra yenidən cəhd edin.');
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
                      'Yeni parol',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hesabınız üçün yeni parol təyin edin.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 26),
                    PremiumTextField(
                      controller: _passwordController,
                      label: 'Yeni parol',
                      hint: 'Ən azı 8 simvol',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'Parol ən azı 8 simvoldan ibarət olmalıdır.' : null,
                    ),
                    const SizedBox(height: 14),
                    PremiumTextField(
                      controller: _confirmController,
                      label: 'Yeni parol (təkrar)',
                      hint: 'Parolu təkrar yaz',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Parolu təkrar yaz' : null,
                    ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      label: 'Parolu yenilə',
                      loading: _saving,
                      onPressed: _submit,
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
