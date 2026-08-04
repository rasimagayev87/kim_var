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
import '../../../profile/domain/entities/user_profile.dart' show kGenderOptions;
import '../../../profile/presentation/providers/photo_upload_provider.dart';
import '../../../profile/presentation/storage_failure_messages.dart';
import '../providers/auth_providers.dart';

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
  final _bioController = TextEditingController();

  DateTime? _birthDate;
  String? _gender;
  String? _country;
  String? _city;
  File? _pickedPhoto;
  bool _saving = false;

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
    _bioController.dispose();
    super.dispose();
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

    setState(() => _saving = true);

    try {
      await ref.read(authControllerProvider.notifier).completeOnboarding(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            birthDate: _birthDate!,
            gender: _gender!,
            country: _country!,
            city: _city!,
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
                onCountryChanged: (value) => setState(() => _country = value),
                onCityChanged: (value) => setState(() => _city = value),
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
