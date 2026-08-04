import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart' show venueCategoryLabel;
import '../../domain/entities/offer.dart';
import '../../domain/offer_failure.dart';
import '../providers/offer_providers.dart';
import '../widgets/venue_picker_sheet.dart';

/// Only venue owners ever reach this screen (the "+" that opens it
/// lives in the Təkliflər tab, same visibility as everyone else's, but
/// submitting with zero venues is caught by [VenuePickerSheet]'s empty
/// state rather than gating the screen itself — same approach as
/// `CreateVenueScreen` not pre-checking anything before opening).
class CreateOfferScreen extends ConsumerStatefulWidget {
  final Offer? existingOffer;

  const CreateOfferScreen({super.key, this.existingOffer});

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  late final _titleController = TextEditingController(text: widget.existingOffer?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existingOffer?.description ?? '');
  late final _termsController = TextEditingController(text: widget.existingOffer?.terms ?? '');
  late final _fixedPriceController =
      TextEditingController(text: widget.existingOffer?.discountValue?.round().toString() ?? '');
  late final _contactPhoneController = TextEditingController(text: widget.existingOffer?.contactPhone ?? '');
  late final _contactWebsiteController = TextEditingController(text: widget.existingOffer?.contactWebsite ?? '');
  late final _contactInstagramController = TextEditingController(text: widget.existingOffer?.contactInstagram ?? '');

  bool get _isEditing => widget.existingOffer != null;

  late VenueCategory? _category = widget.existingOffer?.category;
  late OfferType? _offerType = widget.existingOffer?.offerType ?? OfferType.discount;
  late double _discountPercent = widget.existingOffer?.discountValue ?? 20;
  late DateTime? _startDate = widget.existingOffer?.startDate ?? DateTime.now();
  late DateTime? _endDate = widget.existingOffer?.endDate ?? DateTime.now().add(const Duration(days: 30));

  /// Only set on create — an offer's venue never changes after
  /// creation (mirrors why `UpdateOfferUseCase` never re-validates one).
  Venue? _selectedVenue;

  late bool _showContactPhone = widget.existingOffer?.showContactPhone ?? false;
  late bool _showContactWebsite = widget.existingOffer?.showContactWebsite ?? false;
  late bool _showContactInstagram = widget.existingOffer?.showContactInstagram ?? false;

  File? _photo;
  bool _submitting = false;
  Set<OfferFieldError> _fieldErrors = {};
  double? _uploadProgress;
  VoidCallback? _cancelUpload;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    _fixedPriceController.dispose();
    _contactPhoneController.dispose();
    _contactWebsiteController.dispose();
    _contactInstagramController.dispose();
    super.dispose();
  }

  Future<void> _pickVenue() async {
    final venue = await showModalBottomSheet<Venue>(
      context: context,
      backgroundColor: ChatLightColors.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))),
      builder: (_) => const VenuePickerSheet(),
    );
    if (venue != null) setState(() => _selectedVenue = venue);
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<VenueCategory>(
      context: context,
      backgroundColor: ChatLightColors.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))),
      builder: (_) => _OfferCategoryPickerSheet(selected: _category),
    );
    if (selected != null) setState(() => _category = selected);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: isStart ? now.subtract(const Duration(days: 1)) : (_startDate ?? now),
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: isStart ? loc.offerStartDatePickerLabel : loc.offerEndDatePickerLabel,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickPhoto() async {
    final loc = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: ChatLightColors.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loc.venuePhotoSheetTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text(loc.venuePhotoGalleryOption, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: Text(loc.venuePhotoCameraOption, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1600,
      maxHeight: 1600,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: loc.venuePhotoCropTitle,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: ChatLightColors.contourLine,
          activeControlsWidgetColor: AppColors.primary,
          backgroundColor: ChatLightColors.bg1,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: loc.venuePhotoCropTitle, aspectRatioLockEnabled: false),
      ],
    );
    if (cropped != null) setState(() => _photo = File(cropped.path));
  }

  double? get _resolvedDiscountValue {
    if (_offerType == OfferType.discount) return _discountPercent;
    if (_offerType == OfferType.fixedPrice) return double.tryParse(_fixedPriceController.text.trim());
    return null;
  }

  Future<void> _submit() async {
    if (!await requireVerified(context, ref)) return;
    if (!mounted) return;
    if (_isEditing) {
      await _submitEdit();
    } else {
      await _submitCreate();
    }
  }

  Future<void> _submitCreate() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _fieldErrors = {};
      _uploadProgress = _photo != null ? 0 : null;
      _cancelUpload = null;
    });

    final loc = AppLocalizations.of(context);
    final venue = _selectedVenue;

    final offerId = await ref.read(offerControllerProvider).createOffer(
          venueId: venue?.id,
          venueName: venue?.name ?? '',
          venuePhotoUrl: venue?.photoUrl,
          lat: venue?.lat,
          lng: venue?.lng,
          address: venue?.address ?? '',
          country: venue?.country,
          title: _titleController.text,
          description: _descriptionController.text,
          category: _category,
          offerType: _offerType,
          discountValue: _resolvedDiscountValue,
          startDate: _startDate,
          endDate: _endDate,
          photo: _photo,
          terms: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
          contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
          showContactPhone: _showContactPhone,
          contactWebsite: _contactWebsiteController.text.trim().isEmpty ? null : _contactWebsiteController.text.trim(),
          showContactWebsite: _showContactWebsite,
          contactInstagram: _contactInstagramController.text.trim().isEmpty ? null : _contactInstagramController.text.trim(),
          showContactInstagram: _showContactInstagram,
          onValidationError: (missing) {
            if (!mounted) return;
            setState(() => _fieldErrors = missing.toSet());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerRequiredFieldsMissing)));
          },
          onError: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerGenericErrorMessage)));
          },
          onUploadProgress: (p) {
            if (!mounted) return;
            setState(() => _uploadProgress = p);
          },
          onUploadTaskReady: (cancel) => _cancelUpload = cancel,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _uploadProgress = null;
      _cancelUpload = null;
    });

    if (offerId != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerCreatedNotice)));
      Navigator.pop(context);
    }
  }

  Future<void> _submitEdit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _fieldErrors = {};
      _uploadProgress = _photo != null ? 0 : null;
      _cancelUpload = null;
    });

    final loc = AppLocalizations.of(context);

    final success = await ref.read(offerControllerProvider).updateOffer(
          offerId: widget.existingOffer!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          category: _category,
          offerType: _offerType,
          discountValue: _resolvedDiscountValue,
          startDate: _startDate,
          endDate: _endDate,
          photo: _photo,
          hasExistingPhoto: widget.existingOffer?.imageUrl != null,
          terms: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
          contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
          showContactPhone: _showContactPhone,
          contactWebsite: _contactWebsiteController.text.trim().isEmpty ? null : _contactWebsiteController.text.trim(),
          showContactWebsite: _showContactWebsite,
          contactInstagram: _contactInstagramController.text.trim().isEmpty ? null : _contactInstagramController.text.trim(),
          showContactInstagram: _showContactInstagram,
          onValidationError: (missing) {
            if (!mounted) return;
            setState(() => _fieldErrors = missing.toSet());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerRequiredFieldsMissing)));
          },
          onError: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerGenericErrorMessage)));
          },
          onUploadProgress: (p) {
            if (!mounted) return;
            setState(() => _uploadProgress = p);
          },
          onUploadTaskReady: (cancel) => _cancelUpload = cancel,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _uploadProgress = null;
      _cancelUpload = null;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerUpdatedNotice)));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        title: Text(
          _isEditing ? loc.offerEditTitle : loc.offerCreateTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: Stack(
        children: [
          const ChatLightBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _OfferPhotoPicker(
                  file: _photo,
                  existingUrl: widget.existingOffer?.imageUrl,
                  hasError: _fieldErrors.contains(OfferFieldError.photo),
                  onPick: _pickPhoto,
                  onRemove: () => setState(() => _photo = null),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerNameLabel),
                _LightTextField(controller: _titleController, hint: loc.offerNameHint, maxLength: 50),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerCategoryLabel),
                _CategoryField(
                  category: _category,
                  hasError: _fieldErrors.contains(OfferFieldError.category),
                  onTap: _pickCategory,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerTypeLabel),
                _OfferTypeSelector(
                  selected: _offerType,
                  onChanged: (t) => setState(() => _offerType = t),
                ),
                if (_offerType == OfferType.discount || _offerType == OfferType.fixedPrice) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(_offerType == OfferType.discount ? loc.offerDiscountAmountLabel : loc.offerFixedPriceLabel),
                  if (_offerType == OfferType.discount)
                    _DiscountSlider(
                      value: _discountPercent,
                      onChanged: (v) => setState(() => _discountPercent = v),
                    )
                  else
                    _LightTextField(
                      controller: _fixedPriceController,
                      hint: loc.offerFixedPriceHint,
                      errorText: _fieldErrors.contains(OfferFieldError.discountValue) ? loc.venueFieldRequiredError : null,
                      keyboardType: TextInputType.number,
                    ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerDescriptionLabel),
                _LightTextField(
                  controller: _descriptionController,
                  hint: loc.offerDescriptionHint,
                  maxLength: 200,
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerValidityPeriodLabel),
                _DateRangeRow(
                  loc: loc,
                  startDate: _startDate,
                  endDate: _endDate,
                  dateFormat: dateFormat,
                  onPickStart: () => _pickDate(isStart: true),
                  onPickEnd: () => _pickDate(isStart: false),
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(loc.offerVenuePickerLabel),
                  _VenuePickerField(
                    venue: _selectedVenue,
                    hasError: _fieldErrors.contains(OfferFieldError.venue),
                    onTap: _pickVenue,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerTermsLabel),
                _LightTextField(controller: _termsController, hint: loc.offerTermsHint, maxLength: 200, maxLines: 3),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerAdditionalInfoLabel),
                _ContactToggleField(
                  icon: Icons.call_outlined,
                  controller: _contactPhoneController,
                  hint: loc.offerContactPhoneHint,
                  value: _showContactPhone,
                  onChanged: (v) => setState(() => _showContactPhone = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ContactToggleField(
                  icon: Icons.public,
                  controller: _contactWebsiteController,
                  hint: loc.offerContactWebsiteHint,
                  value: _showContactWebsite,
                  onChanged: (v) => setState(() => _showContactWebsite = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ContactToggleField(
                  icon: Icons.camera_alt_outlined,
                  controller: _contactInstagramController,
                  hint: loc.offerContactInstagramHint,
                  value: _showContactInstagram,
                  onChanged: (v) => setState(() => _showContactInstagram = v),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                if (_submitting && _uploadProgress != null)
                  _UploadProgressCard(progress: _uploadProgress!, onCancel: _cancelUpload)
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                        foregroundColor: ChatLightColors.contourLine,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                        elevation: 0,
                        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: ChatLightColors.contourLine),
                            )
                          : Text(_isEditing ? loc.venueSaveButton : loc.offerSubmitButton),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
    );
  }
}

/// Same bare-TextField-inside-a-styled-Container pattern as Venues'
/// own `_LightTextField`, including the same `filled`/`*Border`
/// overrides that fix — see that class's doc comment for the full
/// explanation of why every one of them is required, not cosmetic.
class _LightTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;

  const _LightTextField({
    required this.controller,
    required this.hint,
    this.errorText,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.input),
            border: Border.all(color: hasError ? AppColors.error : ChatLightColors.inkFaint.withValues(alpha: 0.18)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: ChatLightColors.ink),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: ChatLightColors.inkFaint, fontWeight: FontWeight.w400, fontSize: 15.5),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              counterText: '',
              isDense: true,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
        ],
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  final VenueCategory? category;
  final bool hasError;
  final VoidCallback onTap;

  const _CategoryField({required this.category, required this.hasError, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: hasError ? Border.all(color: AppColors.error, width: 1.2) : null,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                    category != null ? venueCategoryIcon(category!) : Icons.category_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    category != null ? venueCategoryLabel(loc, category!) : loc.venueCategoryUnselectedLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                  ),
                ),
                Icon(Icons.chevron_right, color: ChatLightColors.inkFaint, size: 20),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(loc.venueFieldRequiredError, style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
        ],
      ],
    );
  }
}

/// Search + flat filterable category list — same shape as Venues'
/// `_CategoryPickerSheet`; duplicated rather than shared since that
/// one is file-private and this is a small, self-contained widget.
class _OfferCategoryPickerSheet extends StatefulWidget {
  final VenueCategory? selected;

  const _OfferCategoryPickerSheet({required this.selected});

  @override
  State<_OfferCategoryPickerSheet> createState() => _OfferCategoryPickerSheetState();
}

class _OfferCategoryPickerSheetState extends State<_OfferCategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final categories =
        VenueCategory.values.where((c) => query.isEmpty || venueCategoryLabel(loc, c).toLowerCase().contains(query)).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: ChatLightColors.inkFaint.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(loc.offerCategoryFilterTitle, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: ChatLightColors.inkFaint.withValues(alpha: 0.18)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: ChatLightColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink),
                      decoration: InputDecoration(
                        hintText: loc.venueCategorySearchHint,
                        hintStyle: TextStyle(color: ChatLightColors.inkFaint, fontSize: 14.5),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category == widget.selected;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, category),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.14) : ChatLightColors.cardSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(venueCategoryIcon(category), size: 18, color: isSelected ? AppColors.primary : ChatLightColors.ink),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                venueCategoryLabel(loc, category),
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                              ),
                            ),
                            if (isSelected) const Icon(Icons.check, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferTypeSelector extends StatelessWidget {
  final OfferType? selected;
  final ValueChanged<OfferType> onChanged;

  const _OfferTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final options = [
      (OfferType.discount, loc.offerTypeDiscountOption, Icons.percent_rounded),
      (OfferType.gift, loc.offerTypeGiftOption, Icons.card_giftcard_outlined),
      (OfferType.buyOneGetOne, loc.offerTypeBuyOneGetOneOption, Icons.card_travel_outlined),
      (OfferType.fixedPrice, loc.offerTypeFixedPriceOption, Icons.sell_outlined),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (type, label, icon) in options)
          GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected == type ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected == type ? AppColors.primary : ChatLightColors.inkFaint.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: selected == type ? AppColors.primary : ChatLightColors.inkSoft),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected == type ? AppColors.primary : ChatLightColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DiscountSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _DiscountSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.input)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${value.round()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ChatLightColors.ink)),
              const Text('%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ChatLightColors.inkSoft)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: ChatLightColors.cardSurface,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value,
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeRow extends StatelessWidget {
  final AppLocalizations loc;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateFormat dateFormat;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DateRangeRow({
    required this.loc,
    required this.startDate,
    required this.endDate,
    required this.dateFormat,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _DateField(label: loc.offerStartDatePickerLabel, date: startDate, dateFormat: dateFormat, onTap: onPickStart)),
        const SizedBox(width: 10),
        Expanded(child: _DateField(label: loc.offerEndDatePickerLabel, date: endDate, dateFormat: dateFormat, onTap: onPickEnd)),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.date, required this.dateFormat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.input)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint)),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    date != null ? dateFormat.format(date!) : '—',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 15, color: ChatLightColors.inkFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VenuePickerField extends StatelessWidget {
  final Venue? venue;
  final bool hasError;
  final VoidCallback onTap;

  const _VenuePickerField({required this.venue, required this.hasError, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: hasError ? Border.all(color: AppColors.error, width: 1.2) : null,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: venue?.photoUrl != null
                        ? Image.network(venue!.photoUrl!, fit: BoxFit.cover)
                        : Container(
                            color: ChatLightColors.cardSurface,
                            alignment: Alignment.center,
                            child: Icon(
                              venue != null ? venueCategoryIcon(venue!.category) : Icons.storefront_outlined,
                              size: 18,
                              color: ChatLightColors.inkSoft,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue?.name ?? loc.offerVenuePickerHint,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (venue != null && venue!.address.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          venue!.address,
                          style: TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: ChatLightColors.inkFaint, size: 20),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(loc.venueFieldRequiredError, style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
        ],
      ],
    );
  }
}

class _ContactToggleField extends StatelessWidget {
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ContactToggleField({
    required this.icon,
    required this.controller,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.input)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ChatLightColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: ChatLightColors.inkFaint, fontSize: 14.5),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: ChatLightColors.cardSurface,
          ),
        ],
      ),
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  final double progress;
  final VoidCallback? onCancel;

  const _UploadProgressCard({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final percent = (progress.clamp(0, 1) * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(loc.venueUploadingLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
              ),
              Text('$percent%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: ChatLightColors.cardSurface,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
              ),
              child: Text(loc.venueUploadCancelButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferPhotoPicker extends StatelessWidget {
  final File? file;
  final String? existingUrl;
  final bool hasError;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _OfferPhotoPicker({
    required this.file,
    this.existingUrl,
    required this.hasError,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final hasExisting = file == null && (existingUrl?.isNotEmpty ?? false);
    final hasAnyPhoto = file != null || hasExisting;

    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 176,
        width: double.infinity,
        decoration: BoxDecoration(
          color: ChatLightColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: hasError ? AppColors.error : ChatLightColors.inkFaint.withValues(alpha: 0.35),
            width: hasError ? 1.2 : 1.4,
          ),
          image: file != null
              ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
              : hasExisting
                  ? DecorationImage(image: NetworkImage(existingUrl!), fit: BoxFit.cover)
                  : null,
        ),
        child: !hasAnyPhoto
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(loc.offerPhotoLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
                ],
              )
            : file == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
