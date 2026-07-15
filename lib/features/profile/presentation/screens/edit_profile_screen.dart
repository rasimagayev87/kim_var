import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/country_city_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _bioController;
  late final TextEditingController _ageController;
  String? _country;
  String? _city;
  File? _pickedPhotoFile;
  String? _existingPhotoUrl;
  bool _photoRemoved = false;
  late Set<String> _selectedInterests;
  String? _gender;
  String? _language;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileControllerProvider);
    _bioController = TextEditingController(text: profile.bio);
    _ageController = TextEditingController(text: profile.age?.toString() ?? '');
    _country = profile.country;
    _city = profile.city;
    _existingPhotoUrl = profile.photoUrl;
    _selectedInterests = profile.interests.toSet();
    _gender = profile.gender;
    _language = profile.language;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _pickedPhotoFile = File(picked.path);
      _photoRemoved = false;
    });
  }

  void _removePhoto() => setState(() {
        _pickedPhotoFile = null;
        _existingPhotoUrl = null;
        _photoRemoved = true;
      });

  Future<void> _handleSave() async {
    setState(() => _saving = true);

    try {
      await ref.read(profileControllerProvider.notifier).save(
            localPhotoFile: _pickedPhotoFile,
            clearPhoto: _photoRemoved,
            bio: _bioController.text.trim(),
            interests: _selectedInterests.toList(),
            age: int.tryParse(_ageController.text.trim()),
            gender: _gender,
            language: _language,
            country: _country,
            city: _city,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yadda saxlanmadı: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: const Text('Profili redaktə et'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                      image: _pickedPhotoFile != null
                          ? DecorationImage(image: FileImage(_pickedPhotoFile!), fit: BoxFit.cover)
                          : (_existingPhotoUrl != null
                              ? DecorationImage(image: NetworkImage(_existingPhotoUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: (_pickedPhotoFile == null && _existingPhotoUrl == null)
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
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Icon(Icons.camera_alt, size: 17, color: Color(0xFF00281E)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_pickedPhotoFile != null || _existingPhotoUrl != null)
              Center(
                child: TextButton(
                  onPressed: _removePhoto,
                  child: const Text('Şəkli sil'),
                ),
              ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PremiumTextField(
                    controller: _ageController,
                    label: 'Yaş',
                    hint: '25',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _DropdownField(
                    label: 'Cins',
                    icon: Icons.wc_outlined,
                    value: _gender,
                    options: kGenderOptions,
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DropdownField(
              label: 'Danışdığın dil',
              icon: Icons.language,
              value: _language,
              options: kLanguageOptions,
              onChanged: (v) => setState(() => _language = v),
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
              'Haqqında',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 200,
              style: const TextStyle(color: AppColors.white, fontSize: 14.5),
              decoration: const InputDecoration(
                hintText: 'Özün haqqında bir neçə cümlə yaz...',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Maraq sahələri',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Oxşar maraqları olan insanlarla daha çox uyğunlaşacaqsan.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kAvailableInterests.map((interest) {
                final selected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedInterests.remove(interest);
                      } else {
                        _selectedInterests.add(interest);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.divider,
                      ),
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
              label: 'Yadda saxla',
              loading: _saving,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: AppColors.card,
      style: const TextStyle(color: AppColors.white, fontSize: 14.5),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
