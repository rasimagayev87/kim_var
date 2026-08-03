import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../providers/auth_providers.dart';

final _usernameFormat = RegExp(r'^[a-zA-Z0-9._]{3,20}$');

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      _showMessage('Parollar uyğun gəlmir.');
      return;
    }

    setState(() => _saving = true);
    final username = _usernameController.text.trim();
    final controller = ref.read(authControllerProvider.notifier);

    try {
      final available = await controller.isUsernameAvailable(username);
      if (!available) {
        if (!mounted) return;
        setState(() => _saving = false);
        _showMessage('Bu username artıq istifadə olunur.');
        return;
      }

      await controller.registerWithUsername(username: username, password: _passwordController.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Qeydiyyat tamamlanmadı. Bir az sonra yenidən cəhd edin.');
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
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Qeydiyyatdan keç',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.white),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 28),
                    PremiumTextField(
                      controller: _usernameController,
                      label: 'İstifadəçi adı',
                      hint: 'istifadeci.adi',
                      icon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || !_usernameFormat.hasMatch(v.trim())) {
                          return 'Username yalnız hərf, rəqəm, . və _ ola bilər (3-20 simvol).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    PremiumTextField(
                      controller: _passwordController,
                      label: 'Parol',
                      hint: 'Ən azı 8 simvol',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'Parol ən azı 8 simvoldan ibarət olmalıdır.' : null,
                    ),
                    const SizedBox(height: 14),
                    PremiumTextField(
                      controller: _confirmController,
                      label: 'Parol (təkrar)',
                      hint: 'Parolu təkrar yaz',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Parolu təkrar yaz' : null,
                    ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      label: 'Qeydiyyatı tamamla',
                      loading: _saving,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 24),
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
