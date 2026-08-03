import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';

/// Generic 6-digit SMS code entry, reused by both secondary phone
/// flows ("Hesabı təsdiq et" phone-linking and "Parolu unutdum"
/// account recovery) — the UI is identical, only which repository
/// call [onConfirm] makes and what [onSuccess] does next differ.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final String? successMessage;
  final Future<void> Function(WidgetRef ref, String verificationId, String smsCode) onConfirm;
  final Future<void> Function(BuildContext context) onSuccess;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.onConfirm,
    required this.onSuccess,
    this.successMessage,
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
      await widget.onConfirm(ref, widget.verificationId, _codeController.text.trim());
      if (!mounted) return;

      final message = widget.successMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      await widget.onSuccess(context);
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
