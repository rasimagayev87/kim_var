import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/widgets/country_city_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../profile/domain/entities/user_profile.dart' show kAvailableInterests, kGenderOptions;
import '../../../profile/presentation/providers/profile_providers.dart';
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
  final Set<String> _selectedInterests = {};
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Doğum tarixini seç',
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
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğum tarixini seçin')),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cinsini seçin')),
      );
      return;
    }
    if (_country == null || _city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ölkə və şəhəri seçin')),
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
            interests: _selectedInterests.toList(),
          );

      if (_pickedPhoto != null) {
        await ref.read(profileControllerProvider.notifier).save(
              localPhotoFile: _pickedPhoto,
              bio: _bioController.text.trim(),
              interests: _selectedInterests.toList(),
            );
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
        SnackBar(content: Text('Xəta baş verdi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profilini tamamla')),
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
                        border: Border.all(color: AppColors.primary, width: 2),
                        image: _pickedPhoto != null
                            ? DecorationImage(image: FileImage(_pickedPhoto!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _pickedPhoto == null
                          ? const Icon(Icons.person, color: AppColors.primary, size: 46)
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
                          child: const Icon(Icons.camera_alt, size: 17, color: Color(0xFF00281E)),
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
                    'Şəkil əlavə et (keçilə bilər)',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary.withOpacity(0.8)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      controller: _firstNameController,
                      label: 'Ad',
                      hint: 'Rasim',
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad daxil et' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PremiumTextField(
                      controller: _lastNameController,
                      label: 'Soyad',
                      hint: 'Məmmədov',
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Soyad daxil et' : null,
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
                    label: 'Doğum tarixi',
                    hint: 'gg.aa.iiii',
                    icon: Icons.cake_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender,
                isExpanded: true,
                dropdownColor: AppColors.card,
                style: const TextStyle(color: AppColors.white, fontSize: 14.5),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                decoration: const InputDecoration(
                  labelText: 'Cins',
                  prefixIcon: Icon(Icons.wc_outlined, color: AppColors.textSecondary, size: 20),
                ),
                items: kGenderOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ölkə və şəhər',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
              ),
              const SizedBox(height: 10),
              CountryCityPicker(
                initialCountry: _country,
                initialCity: _city,
                onCountryChanged: (value) => setState(() => _country = value),
                onCityChanged: (value) => setState(() => _city = value),
              ),
              const SizedBox(height: 20),
              const Text(
                'Haqqında (keçilə bilər)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(color: AppColors.white, fontSize: 14.5),
                decoration: const InputDecoration(hintText: 'Özün haqqında bir neçə cümlə...'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Maraq sahələri',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kAvailableInterests.map((interest) {
                  final selected = _selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected ? _selectedInterests.remove(interest) : _selectedInterests.add(interest);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                      ),
                      child: Text(
                        interest,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? const Color(0xFF00281E) : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              PremiumButton(
                label: 'Tamamla və davam et',
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
