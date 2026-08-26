import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/country_city_picker.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

/// Same technical constraint as the register screen's username field
/// — see `FirebaseAuthRepository._randomAuthEmail` for why the format
/// still matters even though changing username no longer touches the
/// sign-in credential.
final _usernamePattern = RegExp(r'^[a-zA-Z0-9._]{3,20}$');

enum _UsernameStatus { idle, checking, available, taken, invalidFormat }

/// "Şəxsi məlumatlar" — reached from Settings → Account → Personal
/// info, and from the Settings profile summary card's edit badge.
/// Exactly the 8 fields in the design spec; photo editing lives
/// elsewhere now (Settings' own "Profil şəklini dəyiş" row). Email
/// has its own Account row; spoken-language and interests fields
/// were removed from the product entirely.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _bioController;

  late String _originalUsername;
  DateTime? _birthDate;
  String? _gender;
  String? _country;
  String? _city;
  bool _saving = false;

  Timer? _usernameDebounce;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileControllerProvider);
    _originalUsername = profile.username ?? '';
    _usernameController = TextEditingController(text: _originalUsername);
    _firstNameController = TextEditingController(text: profile.firstName);
    _lastNameController = TextEditingController(text: profile.lastName);
    _bioController = TextEditingController(text: profile.bio);
    _birthDate = profile.birthDate;
    _gender = profile.gender;
    _country = profile.country;
    _city = profile.city;
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty || trimmed.toLowerCase() == _originalUsername.toLowerCase()) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      setState(() => _usernameStatus = _UsernameStatus.invalidFormat);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await ref.read(authControllerProvider.notifier).isUsernameAvailable(trimmed);
      if (!mounted || _usernameController.text.trim() != trimmed) return;
      setState(() => _usernameStatus = available ? _UsernameStatus.available : _UsernameStatus.taken);
    });
  }

  Future<void> _pickBirthDate() async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: loc.birthDatePickerHelpText,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _handleSave() async {
    final loc = AppLocalizations.of(context);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.fieldFirstNameRequiredError)));
      return;
    }
    if (lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.fieldLastNameRequiredError)));
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.onboardingSelectBirthDateError)));
      return;
    }

    final newUsername = _usernameController.text.trim();
    final usernameChanged = newUsername.toLowerCase() != _originalUsername.toLowerCase();
    if (usernameChanged &&
        (newUsername.isEmpty ||
            _usernameStatus == _UsernameStatus.taken ||
            _usernameStatus == _UsernameStatus.invalidFormat ||
            _usernameStatus == _UsernameStatus.checking)) {
      return;
    }

    setState(() => _saving = true);

    try {
      if (usernameChanged) {
        await ref.read(authControllerProvider.notifier).updateUsername(
              oldUsername: _originalUsername,
              newUsername: newUsername,
            );
        _originalUsername = newUsername;
      }

      await ref.read(profileControllerProvider.notifier).save(
            firstName: firstName,
            lastName: lastName,
            birthDate: _birthDate!,
            bio: _bioController.text.trim(),
            gender: _gender,
            country: _country,
            city: _city,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.saveFailedError(e.toString()))));
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.profileSaveSuccessMessage)));
    Navigator.pop(context);
  }

  bool get _canSubmit {
    if (_firstNameController.text.trim().isEmpty) return false;
    if (_lastNameController.text.trim().isEmpty) return false;
    if (_birthDate == null) return false;

    final newUsername = _usernameController.text.trim();
    final usernameChanged = newUsername.toLowerCase() != _originalUsername.toLowerCase();
    if (usernameChanged &&
        (newUsername.isEmpty ||
            _usernameStatus == _UsernameStatus.taken ||
            _usernameStatus == _UsernameStatus.invalidFormat ||
            _usernameStatus == _UsernameStatus.checking)) {
      return false;
    }
    return true;
  }

  String? _usernameHelperText(AppLocalizations loc) {
    switch (_usernameStatus) {
      case _UsernameStatus.checking:
        return loc.registerUsernameCheckingLabel;
      case _UsernameStatus.taken:
        return loc.registerUsernameTakenError;
      case _UsernameStatus.invalidFormat:
        return loc.registerUsernameInvalidFormatError;
      case _UsernameStatus.available:
      case _UsernameStatus.idle:
        return null;
    }
  }

  Color _usernameHelperColor() {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:
      case _UsernameStatus.invalidFormat:
        return AppColors.error;
      case _UsernameStatus.checking:
      case _UsernameStatus.available:
      case _UsernameStatus.idle:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final usernameHelper = _usernameHelperText(loc);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.editProfileTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(
              loc.personalInfoSubtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(height: 1.4),
            ),
            const SizedBox(height: 24),
            PremiumTextField(
              controller: _usernameController,
              label: loc.registerUsernameLabel,
              hint: loc.registerUsernameHint,
              icon: Icons.person_outline,
              onChanged: _onUsernameChanged,
              suffixIcon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
            ),
            if (usernameHelper != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(usernameHelper, style: AppTextStyles.caption.copyWith(color: _usernameHelperColor())),
              ),
            ],
            const SizedBox(height: 16),
            PremiumTextField(
              controller: _firstNameController,
              label: loc.fieldFirstNameLabel,
              hint: loc.fieldFirstNameHint,
              icon: Icons.person_outline,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              controller: _lastNameController,
              label: loc.fieldLastNameLabel,
              hint: loc.fieldLastNameHint,
              icon: Icons.person_outline,
              onChanged: (_) => setState(() {}),
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
                  icon: Icons.calendar_today_outlined,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_outlined, color: AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(loc.fieldGenderLabel, style: AppTextStyles.caption),
            const SizedBox(height: 8),
            _GenderSegmentedControl(
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),
            CountryCityPicker(
              initialCountry: _country,
              initialCity: _city,
              onCountryChanged: (value) => setState(() => _country = value),
              onCityChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 20),
            Text(loc.sectionAboutTitle, style: AppTextStyles.sectionTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 200,
              style: AppTextStyles.body.copyWith(fontSize: 15.5),
              decoration: InputDecoration(
                hintText: loc.bioHintEdit,
                prefixIcon: const Icon(Icons.format_quote_outlined, color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 28),
            PremiumButton(
              label: loc.saveButton,
              loading: _saving,
              onPressed: _canSubmit ? _handleSave : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderSegmentedControl extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _GenderSegmentedControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final option in kGenderOptions.take(2))
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value == option ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option == kGenderOptions.first ? Icons.male_outlined : Icons.female_outlined,
                        size: 18,
                        color: value == option ? AppColors.onAccent : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value == option ? AppColors.onAccent : AppColors.textSecondary,
                        ),
                      ),
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
