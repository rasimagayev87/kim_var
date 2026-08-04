import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'country_dial_code.dart';

/// Step 1 of any phone-verification flow (account verification,
/// password recovery): country picker + number entry. Deliberately
/// just the input, no Scaffold/background — the enclosing screen
/// owns that, so this is reusable across different flow chrome.
class PhoneNumberEntryStep extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final String? errorText;
  final Future<void> Function(String fullPhoneNumber) onSubmit;

  const PhoneNumberEntryStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onSubmit,
    this.errorText,
  });

  @override
  State<PhoneNumberEntryStep> createState() => _PhoneNumberEntryStepState();
}

class _PhoneNumberEntryStepState extends State<PhoneNumberEntryStep> {
  final _phoneController = TextEditingController();
  CountryDialCode _selectedCountry = kCountryDialCodes.first;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _pickCountry() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(loc.pickCountryTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: kCountryDialCodes.length,
                    itemBuilder: (context, index) {
                      final country = kCountryDialCodes[index];
                      return ListTile(
                        leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(country.name, style: AppTextStyles.body.copyWith(fontSize: 15.5)),
                        trailing: Text(country.dialCode, style: AppTextStyles.bodySmall),
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
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: AppTextStyles.h1.copyWith(fontSize: 30)),
        const SizedBox(height: 10),
        Text(widget.subtitle, style: AppTextStyles.caption),
        const SizedBox(height: 28),
        Row(
          children: [
            GestureDetector(
              onTap: _pickCountry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCountry.dialCode,
                      style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_outlined, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.body.copyWith(fontSize: 15.5),
                decoration: InputDecoration(hintText: loc.phoneAuthNumberHint),
              ),
            ),
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 12),
          Text(widget.errorText!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 22),
        PremiumButton(
          label: loc.phoneAuthContinueButton,
          loading: widget.loading,
          onPressed: () {
            final digits = _phoneController.text.trim();
            if (digits.length < 7) return;
            widget.onSubmit('${_selectedCountry.dialCode}$digits');
          },
        ),
      ],
    );
  }
}

/// Step 2: 6-digit code entry with a 2-minute countdown before resend
/// unlocks. Shared by every phone-verification flow — the one place
/// this timer/resend behavior is implemented.
class OtpCodeEntryStep extends StatefulWidget {
  final String phoneNumber;
  final bool loading;
  final String? errorText;
  final Future<void> Function(String code) onConfirm;
  final Future<void> Function() onResend;

  const OtpCodeEntryStep({
    super.key,
    required this.phoneNumber,
    required this.loading,
    required this.onConfirm,
    required this.onResend,
    this.errorText,
  });

  @override
  State<OtpCodeEntryStep> createState() => _OtpCodeEntryStepState();
}

class _OtpCodeEntryStepState extends State<OtpCodeEntryStep> {
  static const _codeValidSeconds = 120;

  final _codeController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _codeValidSeconds;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _codeValidSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleResend() async {
    setState(() => _resending = true);
    await widget.onResend();
    if (!mounted) return;
    setState(() => _resending = false);
    _startCountdown();
  }

  String get _formattedCountdown {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final canResend = _secondsLeft <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(loc.otpTitle, style: AppTextStyles.h1.copyWith(fontSize: 30)),
        const SizedBox(height: 10),
        Text(loc.otpSubtitle(widget.phoneNumber), style: AppTextStyles.caption),
        const SizedBox(height: 28),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.white, fontSize: 24, letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            hintText: loc.otpCodeHint,
            errorText: widget.errorText,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: _resending ? null : _handleResend,
                  child: _resending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Text(loc.otpResendButton),
                )
              : Text(loc.otpResendWaitLabel(_formattedCountdown), style: AppTextStyles.caption),
        ),
        const SizedBox(height: 8),
        PremiumButton(
          label: loc.otpConfirmButton,
          loading: widget.loading,
          onPressed: () {
            final code = _codeController.text.trim();
            if (code.length != 6) return;
            widget.onConfirm(code);
          },
        ),
      ],
    );
  }
}
