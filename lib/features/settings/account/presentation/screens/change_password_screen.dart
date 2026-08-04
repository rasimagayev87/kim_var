import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/premium_button.dart';
import '../../../../../core/widgets/premium_text_field.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';

/// Settings → Account → "Parolu dəyiş" — only reachable for a verified
/// account (gated by `requireVerified()` at the row that opens this).
/// Requires the current password (reauthentication) before changing.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    setState(() => _error = null);

    final newPassword = _newController.text;
    if (newPassword.length < 8) {
      setState(() => _error = loc.registerPasswordTooShortError);
      return;
    }
    if (newPassword != _confirmController.text) {
      setState(() => _error = loc.registerPasswordMismatchError);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _currentController.text,
            newPassword: newPassword,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.changePasswordSuccessMessage)));
      Navigator.pop(context);
    } on fb.FirebaseAuthException catch (e) {
      if (!mounted) return;
      final wrongCurrent = e.code == 'wrong-password' || e.code == 'invalid-credential';
      setState(() {
        _loading = false;
        _error = wrongCurrent ? loc.changePasswordWrongCurrentError : loc.changePasswordGenericError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loc.changePasswordGenericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.changePasswordTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumTextField(
                controller: _currentController,
                label: loc.changePasswordCurrentLabel,
                hint: loc.changePasswordCurrentHint,
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 16),
              PremiumTextField(
                controller: _newController,
                label: loc.changePasswordNewLabel,
                hint: loc.changePasswordNewHint,
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 16),
              PremiumTextField(
                controller: _confirmController,
                label: loc.changePasswordConfirmLabel,
                hint: loc.changePasswordConfirmHint,
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 22),
              PremiumButton(
                label: loc.changePasswordSubmitButton,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
