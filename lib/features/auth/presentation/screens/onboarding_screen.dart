import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/widgets/country_city_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../profile/domain/entities/user_profile.dart' show kBusinessStatusActive, kBusinessStatusNone, kGenderOptions;
import '../../../profile/presentation/providers/photo_upload_provider.dart';
import '../../../profile/presentation/storage_failure_messages.dart';
import '../providers/auth_providers.dart';
import '../widgets/country_dial_code.dart';

/// Shown exactly once, right after a user's very first successful
/// sign-in (any provider), to collect the data needed to create
/// their Firestore profile.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  DateTime? _birthDate;
  String? _gender;
  String? _country;
  String? _city;
  String? _businessStatus;
  File? _pickedPhoto;
  bool _saving = false;

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9._]{3,20}$');

  Timer? _usernameCheckDebounce;
  bool? _usernameAvailable;
  bool _checkingUsername = false;

  // Tracks the dial-code prefix this screen itself last wrote into
  // [_phoneController] (see [_applyDialCodeForCountry]) — lets a
  // country change re-prefix the field without clobbering digits the
  // user already typed after it.
  String? _autoDialCode;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _usernameCheckDebounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameCheckDebounce?.cancel();
    setState(() {
      _usernameAvailable = null;
      _checkingUsername = false;
    });

    final trimmed = value.trim();
    if (!_usernamePattern.hasMatch(trimmed)) return;

    _usernameCheckDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _checkingUsername = true);
      final available = await ref.read(authControllerProvider.notifier).isUsernameAvailable(trimmed);
      if (!mounted || _usernameController.text.trim() != trimmed) return;
      setState(() {
        _usernameAvailable = available;
        _checkingUsername = false;
      });
    });
  }

  /// Auto-fills [_phoneController] with the new country's dial code —
  /// per product decision, this ALWAYS runs a country change (even
  /// after the user has typed digits): it only ever replaces the
  /// prefix this screen itself wrote in ([_autoDialCode]), so an
  /// already-typed local number is preserved, re-prefixed under the
  /// new code.
  void _applyDialCodeForCountry(String? country) {
    final dialCode = _dialCodeFor(country);
    final current = _phoneController.text;
    final rest = _autoDialCode != null && current.startsWith(_autoDialCode!)
        ? current.substring(_autoDialCode!.length)
        : (_autoDialCode == null ? current : '');
    _autoDialCode = dialCode;
    _phoneController.text = '$dialCode $rest'.trimRight();
    _phoneController.selection = TextSelection.collapsed(offset: _phoneController.text.length);
  }

  String _dialCodeFor(String? country) {
    for (final entry in kCountryDialCodes) {
      if (entry.name == country) return entry.dialCode;
    }
    return kCountryDialCodes.first.dialCode;
  }

  Future<void> _pickBirthDate() async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: loc.birthDatePickerHelpText,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pickedPhoto = File(picked.path));
  }

  Future<void> _requestPermissionsThenContinue() async {
    // Location: reuses the same controller the map uses, which
    // handles the system permission dialog itself.
    unawaited(ref.read(locationControllerProvider.notifier).refresh());

    // Notifications: real system permission request (Android 13+),
    // ready for when push notifications are wired up.
    await Permission.notification.request();
  }

  Future<void> _finish() async {
    final loc = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final username = _usernameController.text.trim();
    if (_usernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.onboardingUsernameUnavailableError)),
      );
      return;
    }
    final phone = _phoneController.text.trim();
    if (_autoDialCode == null || phone == _autoDialCode || phone.length <= _autoDialCode!.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.onboardingPhoneRequiredError)),
      );
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.onboardingSelectBirthDateError)),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.onboardingSelectGenderError)),
      );
      return;
    }
    if (_country == null || _city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.onboardingSelectCountryCityError)),
      );
      return;
    }
    if (_businessStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.onboardingSelectBusinessStatusError)),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ref.read(authControllerProvider.notifier).completeOnboarding(
            username: username,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            birthDate: _birthDate!,
            gender: _gender!,
            country: _country!,
            city: _city!,
            phoneNumber: phone.replaceAll(' ', ''),
            businessStatus: _businessStatus!,
            bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
          );

      if (_pickedPhoto != null) {
        // Photo is optional here, so a failure shouldn't block onboarding —
        // the profile document itself was already created above. The user
        // can retry from the edit-profile screen if this fails.
        await ref.read(photoUploadControllerProvider.notifier).upload(_pickedPhoto!);
        final uploadState = ref.read(photoUploadControllerProvider);
        if (uploadState.status == PhotoUploadStatus.error && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uploadState.failureType != null
                    ? localizedStorageFailureMessage(loc, uploadState.failureType!)
                    : loc.onboardingPhotoUploadFailedError,
              ),
            ),
          );
        }
      }

      await _requestPermissionsThenContinue();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorWithDetails(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(loc.onboardingAppBarTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.divider, width: 2),
                        image: _pickedPhoto != null
                            ? DecorationImage(image: FileImage(_pickedPhoto!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _pickedPhoto == null
                          ? const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 46)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                          child: const Icon(Icons.camera_alt_outlined, size: 17, color: AppColors.onAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    loc.onboardingPhotoOptionalLabel,
                    style: AppTextStyles.caption,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      controller: _firstNameController,
                      label: loc.fieldFirstNameLabel,
                      hint: loc.fieldFirstNameHint,
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty) ? loc.fieldFirstNameRequiredError : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PremiumTextField(
                      controller: _lastNameController,
                      label: loc.fieldLastNameLabel,
                      hint: loc.fieldLastNameHint,
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty) ? loc.fieldLastNameRequiredError : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PremiumTextField(
                controller: _usernameController,
                label: loc.fieldUsernameLabel,
                hint: loc.fieldUsernameHint,
                icon: Icons.alternate_email,
                onChanged: _onUsernameChanged,
                validator: (v) {
                  final trimmed = v?.trim() ?? '';
                  if (trimmed.isEmpty) return loc.fieldUsernameRequiredError;
                  if (!_usernamePattern.hasMatch(trimmed)) return loc.fieldUsernameInvalidError;
                  return null;
                },
                suffixIcon: _checkingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
                        ),
                      )
                    : _usernameAvailable == null
                        ? null
                        : Icon(
                            _usernameAvailable! ? Icons.check_circle_outline : Icons.error_outline,
                            color: _usernameAvailable! ? AppColors.primary : AppColors.error,
                          ),
              ),
              if (_usernameAvailable == false) ...[
                const SizedBox(height: 6),
                Text(loc.onboardingUsernameUnavailableError, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              PremiumTextField(
                controller: _phoneController,
                label: loc.fieldPhoneLabel,
                hint: loc.fieldPhoneHint,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final trimmed = v?.trim() ?? '';
                  if (_autoDialCode == null || trimmed.length <= _autoDialCode!.length) {
                    return loc.onboardingPhoneRequiredError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickBirthDate,
                child: AbsorbPointer(
                  child: PremiumTextField(
                    controller: TextEditingController(
                      text: _birthDate == null ? '' : DateFormat('dd.MM.yyyy').format(_birthDate!),
                    ),
                    label: loc.fieldBirthDateLabel,
                    hint: loc.fieldBirthDateHint,
                    icon: Icons.cake_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender,
                isExpanded: true,
                dropdownColor: AppColors.card,
                style: AppTextStyles.body.copyWith(fontSize: 15.5),
                icon: const Icon(Icons.keyboard_arrow_down_outlined, color: AppColors.textSecondary),
                decoration: InputDecoration(
                  labelText: loc.fieldGenderLabel,
                  prefixIcon: const Icon(Icons.wc_outlined, color: AppColors.textSecondary, size: 20),
                ),
                items: kGenderOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 20),
              Text(loc.sectionCountryCityTitle, style: AppTextStyles.sectionTitle.copyWith(fontSize: 20)),
              const SizedBox(height: 12),
              CountryCityPicker(
                initialCountry: _country,
                initialCity: _city,
                onCountryChanged: (value) => setState(() {
                  _country = value;
                  _applyDialCodeForCountry(value);
                }),
                onCityChanged: (value) => setState(() => _city = value),
              ),
              const SizedBox(height: 24),
              Text(loc.sectionBusinessStatusTitle, style: AppTextStyles.sectionTitle.copyWith(fontSize: 20)),
              const SizedBox(height: 6),
              Text(loc.sectionBusinessStatusSubtitle, style: AppTextStyles.caption),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BusinessStatusOption(
                      label: loc.businessStatusActiveLabel,
                      selected: _businessStatus == kBusinessStatusActive,
                      onTap: () => setState(() => _businessStatus = kBusinessStatusActive),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BusinessStatusOption(
                      label: loc.businessStatusNoneLabel,
                      selected: _businessStatus == kBusinessStatusNone,
                      onTap: () => setState(() => _businessStatus = kBusinessStatusNone),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(loc.sectionAboutOptionalTitle, style: AppTextStyles.sectionTitle.copyWith(fontSize: 20)),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 200,
                style: AppTextStyles.body.copyWith(fontSize: 15.5),
                decoration: InputDecoration(hintText: loc.bioHintOnboarding),
              ),
              const SizedBox(height: 32),
              PremiumButton(
                label: loc.onboardingFinishButton,
                loading: _saving,
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One selectable card in the "Biznes fəaliyyəti" pair — a plain
/// 2-way choice, not a full radio-group widget, since this is the
/// only place in the app that needs exactly this shape today.
class _BusinessStatusOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BusinessStatusOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
