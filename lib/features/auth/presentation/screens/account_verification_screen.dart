import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../widgets/phone_verification_steps.dart';

enum _Step { phoneEntry, otpEntry }

/// "Hesabı təsdiq et" — links a phone number to the currently
/// signed-in account via OTP, then flips `isVerified` to true. This
/// is what [requireVerified] routes to when a gated action is
/// blocked. Linking (not signing in) also makes the phone usable as a
/// recovery credential later — see the forgot-password flow.
class AccountVerificationScreen extends ConsumerStatefulWidget {
  const AccountVerificationScreen({super.key});

  @override
  ConsumerState<AccountVerificationScreen> createState() => _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends ConsumerState<AccountVerificationScreen> {
  _Step _step = _Step.phoneEntry;
  String? _verificationId;
  String _phoneNumber = '';
  bool _loading = false;
  String? _error;

  Future<void> _submitPhone(String fullPhoneNumber) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final taken = await ref.read(authControllerProvider.notifier).isPhoneNumberTaken(fullPhoneNumber);
      if (taken) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = loc.accountVerificationPhoneTakenError;
        });
        return;
      }

      _phoneNumber = fullPhoneNumber;
      await ref.read(authControllerProvider.notifier).startPhoneLinkVerification(
        phoneNumber: fullPhoneNumber,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _verificationId = verificationId;
            _step = _Step.otpEntry;
          });
        },
        onAutoVerified: _handleSuccess,
        onFailed: (code) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = _messageForCode(loc, code);
          });
        },
      );
    } catch (e, st) {
      logError('account_verification_screen.submitPhone', e, st);
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
      await ref.read(authControllerProvider.notifier).confirmPhoneLink(
            verificationId: _verificationId!,
            smsCode: code,
            phoneNumber: _phoneNumber,
          );
      if (!mounted) return;
      _handleSuccess();
    } on fb.FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageForCode(loc, e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loc.otpInvalidCodeError;
      });
    }
  }

  Future<void> _resend() => _submitPhone(_phoneNumber);

  void _handleSuccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).accountVerificationSuccessMessage)),
    );
    Navigator.pop(context);
  }

  String _messageForCode(AppLocalizations loc, String? code) {
    if (code == 'credential-already-in-use' || code == 'account-exists-with-different-credential') {
      return loc.accountVerificationPhoneTakenError;
    }
    return loc.phoneAuthVerificationFailedError;
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
                      title: loc.accountVerificationTitle,
                      subtitle: loc.accountVerificationSubtitle,
                      loading: _loading,
                      errorText: _error,
                      onSubmit: _submitPhone,
                    )
                  else
                    OtpCodeEntryStep(
                      phoneNumber: _phoneNumber,
                      loading: _loading,
                      errorText: _error,
                      onConfirm: _confirmCode,
                      onResend: _resend,
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
