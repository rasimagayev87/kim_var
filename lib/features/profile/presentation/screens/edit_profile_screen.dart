import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
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

import '../../../../core/widgets/pressable.dart';

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
  late final TextEditingController _phoneController;

  late String _originalUsername;
  late String _originalFirstName;
  late String _originalLastName;
  late DateTime? _originalBirthDate;
  late String? _originalPhone;
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
    _originalFirstName = profile.firstName;
    _originalLastName = profile.lastName;
    _originalBirthDate = profile.birthDate;
    _originalPhone = profile.phoneNumber;
    _phoneController = TextEditingController(text: profile.phoneNumber ?? '');
    _birthDate = profile.birthDate;
    _gender = profile.gender;
    _country = profile.country;
    _city = profile.city;
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == _originalUsername.toLowerCase()) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      setState(() => _usernameStatus = _UsernameStatus.invalidFormat);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await ref
          .read(authControllerProvider.notifier)
          .isUsernameAvailable(trimmed);
      if (!mounted || _usernameController.text.trim() != trimmed) return;
      setState(
        () => _usernameStatus = available
            ? _UsernameStatus.available
            : _UsernameStatus.taken,
      );
    });
  }

  /// Same bounds as the onboarding picker — `firstDate` 100 years back,
  /// `lastDate` exactly 18 years ago. The 18+ rule is enforced server
  /// side by `updateProfileDetails`; this only keeps the wheel from
  /// offering a date the server would reject.
  Future<void> _pickBirthDate() async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: loc.birthDatePickerHelpText,
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _handleSave() async {
    final loc = AppLocalizations.of(context);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.fieldFirstNameRequiredError)));
      return;
    }
    if (lastName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.fieldLastNameRequiredError)));
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.onboardingSelectBirthDateError)),
      );
      return;
    }

    final newUsername = _usernameController.text.trim();
    final usernameChanged =
        newUsername.toLowerCase() != _originalUsername.toLowerCase();
    if (usernameChanged &&
        (newUsername.isEmpty ||
            _usernameStatus == _UsernameStatus.taken ||
            _usernameStatus == _UsernameStatus.invalidFormat ||
            _usernameStatus == _UsernameStatus.checking)) {
      return;
    }

    final phone = _phoneController.text.trim();

    setState(() => _saving = true);

    try {
      // ONE call, one server-side transaction. This used to be
      // `updateUsername()` followed by `save()`; when the second failed
      // the first had already committed and the account was left with a
      // new handle and the old name, with nothing on screen saying so.
      //
      // Only CHANGED fields are sent. That is not an optimisation — the
      // birth date may be corrected exactly once ever, so re-sending an
      // untouched value would spend that one correction on a save the
      // user made for an unrelated field.
      await ref
          .read(profileControllerProvider.notifier)
          .save(
            firstName: firstName == _originalFirstName ? null : firstName,
            lastName: lastName == _originalLastName ? null : lastName,
            username: usernameChanged ? newUsername : null,
            birthDate: _birthDate == _originalBirthDate ? null : _birthDate,
            bio: _bioController.text.trim(),
            gender: _gender,
            country: _country,
            city: _city,
            phoneNumber: phone == (_originalPhone ?? '') ? null : phone,
          );
      _originalUsername = newUsername;
      _originalFirstName = firstName;
      _originalLastName = lastName;
      _originalBirthDate = _birthDate;
      _originalPhone = phone;
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // `updateProfileDetails` returns a complete Azerbaijani sentence
      // naming the field and, for a cooldown, the days left. Showing it
      // verbatim is the whole point of moving off `permission-denied`,
      // which told the user neither what failed nor when to retry.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? loc.saveFailedError(e.code))),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.saveFailedError(e.toString()))),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.profileSaveSuccessMessage)));
    Navigator.pop(context);
  }

  bool get _canSubmit {
    if (_firstNameController.text.trim().isEmpty) return false;
    if (_lastNameController.text.trim().isEmpty) return false;
    if (_birthDate == null) return false;

    final newUsername = _usernameController.text.trim();
    final usernameChanged =
        newUsername.toLowerCase() != _originalUsername.toLowerCase();
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
      backgroundColor: AppColors.background,
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
              suffixIcon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            if (usernameHelper != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  usernameHelper,
                  style: AppTextStyles.caption.copyWith(
                    color: _usernameHelperColor(),
                  ),
                ),
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
            // Doğum tarixi ÖMÜRDƏ BİR DƏFƏ düzəldilə bilər — bu sahə
            // əvvəllər tamamilə toxunulmaz idi (`AbsorbPointer`), yəni
            // qeydiyyatda səhv yazan istifadəçi onu heç vaxt düzəldə
            // bilmirdi və ad günü kampaniyaları onun üçün əbədi yanlış
            // günə düşürdü. Serverdə `updateProfileDetails` həm 18+
            // qapısını, həm də bir dəfəlik limiti saxlayır; buradakı
            // `lastDate` yalnız UX-dir.
            //
            // Köməkçi mətn qəsdən gün/ay sırasını göstərir: istifadəçi
            // sıranı səhv salsa, ad günü təklifləri yanlış tarixdə gedir
            // və ikinci düzəliş yoxdur.
            Pressable(
              onTap: _saving ? null : _pickBirthDate,
              child: AbsorbPointer(
                child: PremiumTextField(
                  controller: TextEditingController(
                    text: _birthDate == null
                        ? ''
                        : DateFormat('dd.MM.yyyy').format(_birthDate!),
                  ),
                  label: loc.fieldBirthDateLabel,
                  hint: loc.fieldBirthDateHint,
                  icon: Icons.calendar_today_outlined,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(loc.fieldBirthDateHelper, style: AppTextStyles.caption),
            const SizedBox(height: 16),
            PremiumTextField(
              controller: _phoneController,
              label: loc.fieldPhoneLabel,
              hint: loc.fieldPhoneHint,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
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
            Text(
              loc.sectionAboutTitle,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 200,
              style: AppTextStyles.body.copyWith(fontSize: 15.5),
              decoration: InputDecoration(
                hintText: loc.bioHintEdit,
                prefixIcon: const Icon(
                  Icons.format_quote_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
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
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final option in kGenderOptions.take(2))
            Expanded(
              child: Pressable(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value == option
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option == kGenderOptions.first
                            ? Icons.male_outlined
                            : Icons.female_outlined,
                        size: 18,
                        color: value == option
                            ? AppColors.onAccent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value == option
                              ? AppColors.onAccent
                              : AppColors.textSecondary,
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
