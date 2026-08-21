import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/providers/venue_providers.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart' show venueCategoryLabel;
import '../../domain/entities/offer.dart';
import '../../domain/offer_failure.dart';
import '../providers/offer_providers.dart';
import '../widgets/venue_picker_sheet.dart';

/// `Offer.activeDays` keys, Monday-first — matches
/// `OpeningHours.schedule`'s ISO-weekday order (1=Mon..7=Sun), just as
/// lowercase 3-letter strings since `activeDays` is a plain
/// `List<String>` on the wire, not a weekday-keyed map like
/// `OpeningHours`.
const kAllWeekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

TimeOfDay? _parseTimeOfDay(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Only venue owners ever reach this screen (the "+" that opens it
/// lives in the Təkliflər tab, same visibility as everyone else's, but
/// submitting with zero venues is caught by [VenuePickerSheet]'s empty
/// state rather than gating the screen itself — same approach as
/// `CreateVenueScreen` not pre-checking anything before opening).
class CreateOfferScreen extends ConsumerStatefulWidget {
  final Offer? existingOffer;

  /// Set only when opened from a "peak hour" notification
  /// (`notification_navigation.dart`'s `venue_create_offer` case) —
  /// pre-fills [_CreateOfferScreenState._selectedVenue] once the doc
  /// loads. Still just a default, not a lock: the normal venue picker
  /// stays fully usable, same as the rest of this form.
  final String? preselectedVenueId;

  /// Set only when opened from a "birthday match" notification
  /// (`notification_navigation.dart`'s `birthday_match` case, after it
  /// fetches the `birthdayMatches` doc) — together with
  /// [birthdayTargetUserIds], locks this form into the birthday flow:
  /// [OfferType.birthday] can't be un-picked, validity is fixed to
  /// today (or today+6 with the "Ad günü həftəsi" checkbox), and a
  /// personal-message field appears. See
  /// `_CreateOfferScreenState._isBirthdayOffer`.
  final String? birthdayMatchId;
  final List<String> birthdayTargetUserIds;

  const CreateOfferScreen({
    super.key,
    this.existingOffer,
    this.preselectedVenueId,
    this.birthdayMatchId,
    this.birthdayTargetUserIds = const [],
  });

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> with WidgetsBindingObserver {
  late final _titleController = TextEditingController(text: widget.existingOffer?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existingOffer?.description ?? '');
  late final _termsController = TextEditingController(text: widget.existingOffer?.terms ?? '');
  late final _fixedPriceController =
      TextEditingController(text: widget.existingOffer?.discountValue?.round().toString() ?? '');
  late final _personalMessageController = TextEditingController(text: widget.existingOffer?.personalMessage ?? '');

  bool get _isEditing => widget.existingOffer != null;

  late VenueCategory? _category = widget.existingOffer?.category;
  late OfferType? _offerType =
      widget.existingOffer?.offerType ?? (widget.birthdayMatchId != null ? OfferType.birthday : OfferType.discount);
  late double _discountPercent = widget.existingOffer?.discountValue ?? 20;
  late DateTime? _startDate = widget.existingOffer?.startDate ?? (_isBirthdayOffer ? _todayStart() : DateTime.now());
  late DateTime? _endDate = widget.existingOffer?.endDate ??
      (_isBirthdayOffer ? _birthdayEndDate(_birthdayWeekExtension) : DateTime.now().add(const Duration(days: 30)));

  /// [OfferType.birthday] is never a manual choice (see
  /// `_OfferTypeSelector`'s own doc comment) — true either for a fresh
  /// birthday-match create (see [CreateOfferScreen.birthdayMatchId]) or
  /// when editing an existing birthday offer, both of which lock the
  /// type selector and the validity date range in the UI below.
  bool get _isBirthdayOffer => _offerType == OfferType.birthday;

  /// Whether the existing offer being edited already used the 7-day
  /// "Ad günü həftəsi" window — inferred from its stored date range
  /// rather than a separate persisted flag, since a fresh create
  /// always starts unchecked (1-day default) and this is purely a
  /// UI convenience for re-opening that same choice on edit.
  late bool _birthdayWeekExtension = widget.existingOffer != null &&
      widget.existingOffer!.endDate.difference(widget.existingOffer!.startDate).inDays >= 6;

  static DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _birthdayEndDate(bool weekExtension) {
    final start = _todayStart();
    final end = weekExtension ? start.add(const Duration(days: 6)) : start;
    return DateTime(end.year, end.month, end.day, 23, 59, 59);
  }

  // Only meaningful when `_offerType == OfferType.happyHour` — seeded
  // from the existing offer when editing one, otherwise a sensible
  // default window with every day checked (matches the spec: "default:
  // bütün həftə").
  late TimeOfDay _happyHourStart = _parseTimeOfDay(widget.existingOffer?.activeHours?.start) ?? const TimeOfDay(hour: 15, minute: 0);
  late TimeOfDay _happyHourEnd = _parseTimeOfDay(widget.existingOffer?.activeHours?.end) ?? const TimeOfDay(hour: 17, minute: 0);
  late final Set<String> _activeDays = (widget.existingOffer?.activeDays.isNotEmpty ?? false)
      ? widget.existingOffer!.activeDays.toSet()
      : kAllWeekdayKeys.toSet();

  /// Only set on create — an offer's venue never changes after
  /// creation (mirrors why `UpdateOfferUseCase` never re-validates one).
  Venue? _selectedVenue;

  File? _photo;
  bool _submitting = false;
  Set<OfferFieldError> _fieldErrors = {};
  double? _uploadProgress;
  VoidCallback? _cancelUpload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final venueId = widget.preselectedVenueId;
    if (venueId != null) {
      ref.read(venueRepositoryProvider).watchVenue(venueId).first.then((venue) {
        if (mounted && venue != null) {
          setState(() {
            _selectedVenue = venue;
            _category = venue.category;
          });
        }
      });
    }
  }

  // See the identical comment in create_venue_screen.dart's own
  // `didChangeAppLifecycleState` — same iOS camera-memory-reclaim gap,
  // same recovery via image_picker's documented `retrieveLostData()`.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLostPhoto();
  }

  Future<void> _checkLostPhoto() async {
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.file == null || !mounted) return;
    await _cropAndSetPhoto(response.file!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    _fixedPriceController.dispose();
    _personalMessageController.dispose();
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
    if (venue != null) {
      setState(() {
        _selectedVenue = venue;
        _category = venue.category;
      });
    }
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

  Future<void> _pickHappyHourTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _happyHourStart : _happyHourEnd,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _happyHourStart = picked;
      } else {
        _happyHourEnd = picked;
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
    // See the identical comment in create_venue_screen.dart's own
    // `_pickPhoto` — camera's native dismissal race with the cropper's
    // own presentation, gallery doesn't hit it.
    if (source == ImageSource.camera) await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _cropAndSetPhoto(picked);
  }

  Future<void> _cropAndSetPhoto(XFile picked) async {
    final loc = AppLocalizations.of(context);
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
    if (cropped != null && mounted) setState(() => _photo = File(cropped.path));
  }

  double? get _resolvedDiscountValue {
    if (_offerType == OfferType.discount ||
        _offerType == OfferType.happyHour ||
        _offerType == OfferType.firstVisit ||
        _offerType == OfferType.birthday) {
      return _discountPercent;
    }
    if (_offerType == OfferType.fixedPrice) return double.tryParse(_fixedPriceController.text.trim());
    return null;
  }

  ActiveHours? get _resolvedActiveHours {
    if (_offerType != OfferType.happyHour) return null;
    return ActiveHours(start: _formatTimeOfDay(_happyHourStart), end: _formatTimeOfDay(_happyHourEnd));
  }

  List<String> get _resolvedActiveDays {
    if (_offerType != OfferType.happyHour) return const [];
    return kAllWeekdayKeys.where(_activeDays.contains).toList();
  }

  Future<void> _submit() async {
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

    final result = await ref.read(offerControllerProvider).createOffer(
          venueId: _selectedVenue?.id,
          title: _titleController.text,
          description: _descriptionController.text,
          category: _category,
          offerType: _offerType,
          discountValue: _resolvedDiscountValue,
          startDate: _startDate,
          endDate: _endDate,
          photo: _photo,
          terms: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
          activeHours: _resolvedActiveHours,
          activeDays: _resolvedActiveDays,
          birthdayMatchId: _isBirthdayOffer ? widget.birthdayMatchId : null,
          targetUserIds: _isBirthdayOffer ? widget.birthdayTargetUserIds : const [],
          personalMessage: _isBirthdayOffer && _personalMessageController.text.trim().isNotEmpty
              ? _personalMessageController.text.trim()
              : null,
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

    if (result == null) return;

    if (result.requiresPayment) {
      final checkoutUrl = result.checkoutUrl;
      if (checkoutUrl != null) {
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.offerAwaitingPaymentNotice((result.feeAmount ?? 0).round()))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerCreatedNotice)));
    }
    Navigator.pop(context);
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
          activeHours: _resolvedActiveHours,
          activeDays: _resolvedActiveDays,
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

    // Same "editing a needs_revision OR already-approved offer
    // resubmits it automatically" behavior as CreateVenueScreen
    // ._submitEdit — see `resubmitOffer`'s own doc comment for why an
    // approved offer is included now too.
    final wasApproved = widget.existingOffer?.status == 'approved';
    if (success && (widget.existingOffer?.status == 'needs_revision' || wasApproved)) {
      await ref.read(offerControllerProvider).resubmitOffer(widget.existingOffer!.id);
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _uploadProgress = null;
      _cancelUpload = null;
    });

    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(wasApproved ? loc.offerSentForReReviewNotice : loc.offerUpdatedNotice)));
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
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerTypeLabel),
                if (_isBirthdayOffer)
                  _LockedOfferTypeDisplay(label: loc.offerTypeBirthdayOption)
                else
                  _OfferTypeSelector(
                    selected: _offerType,
                    onChanged: (t) => setState(() => _offerType = t),
                  ),
                if (_offerType == OfferType.discount ||
                    _offerType == OfferType.fixedPrice ||
                    _offerType == OfferType.happyHour ||
                    _offerType == OfferType.firstVisit ||
                    _offerType == OfferType.birthday) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(_offerType == OfferType.fixedPrice ? loc.offerFixedPriceLabel : loc.offerDiscountAmountLabel),
                  if (_offerType == OfferType.fixedPrice)
                    _LightTextField(
                      controller: _fixedPriceController,
                      hint: loc.offerFixedPriceHint,
                      errorText: _fieldErrors.contains(OfferFieldError.discountValue) ? loc.venueFieldRequiredError : null,
                      keyboardType: TextInputType.number,
                    )
                  else
                    _DiscountSlider(
                      value: _discountPercent,
                      onChanged: (v) => setState(() => _discountPercent = v),
                    ),
                ],
                if (_offerType == OfferType.happyHour) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(loc.offerActiveHoursLabel),
                  _ActiveHoursRow(
                    start: _happyHourStart,
                    end: _happyHourEnd,
                    hasError: _fieldErrors.contains(OfferFieldError.activeHours),
                    onPickStart: () => _pickHappyHourTime(isStart: true),
                    onPickEnd: () => _pickHappyHourTime(isStart: false),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel(loc.offerActiveDaysLabel),
                  _ActiveDaysSelector(
                    loc: loc,
                    selectedDays: _activeDays,
                    onToggle: (day) => setState(() {
                      if (_activeDays.contains(day)) {
                        _activeDays.remove(day);
                      } else {
                        _activeDays.add(day);
                      }
                    }),
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
                if (_isBirthdayOffer)
                  _BirthdayValidityDisplay(
                    startDate: _startDate!,
                    endDate: _endDate!,
                    dateFormat: dateFormat,
                    weekExtension: _birthdayWeekExtension,
                    onWeekExtensionChanged: (v) => setState(() {
                      _birthdayWeekExtension = v;
                      _endDate = _birthdayEndDate(v);
                    }),
                  )
                else
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
                  if (_isBirthdayOffer)
                    _LockedOfferTypeDisplay(label: _selectedVenue?.name ?? '')
                  else
                    _VenuePickerField(
                      venue: _selectedVenue,
                      hasError: _fieldErrors.contains(OfferFieldError.venue),
                      onTap: _pickVenue,
                    ),
                  if (_selectedVenue != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _PlacementFeeBanner(venue: _selectedVenue!, loc: loc),
                  ],
                ],
                if (_isBirthdayOffer) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(loc.offerPersonalMessageLabel),
                  _LightTextField(
                    controller: _personalMessageController,
                    hint: loc.offerPersonalMessageHint,
                    maxLength: 100,
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.offerTermsLabel),
                _LightTextField(controller: _termsController, hint: loc.offerTermsHint, maxLength: 200, maxLines: 3),
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

/// Read-only — an offer's category is always its venue's category (see
/// [Offer]'s own doc comment), so this just mirrors whatever venue the
/// owner picked instead of letting them choose a mismatched one.
class _CategoryField extends StatelessWidget {
  final VenueCategory? category;
  final bool hasError;

  const _CategoryField({required this.category, required this.hasError});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              const Icon(Icons.lock_outline_rounded, color: ChatLightColors.inkFaint, size: 18),
            ],
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
      (OfferType.happyHour, loc.offerTypeHappyHourOption, Icons.access_time_filled_rounded),
      (OfferType.firstVisit, loc.offerTypeFirstVisitOption, Icons.card_giftcard_rounded),
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

/// Read-only stand-in for a field the birthday flow has already
/// decided (offer type, venue) — same chip look as a permanently
/// "selected" [_OfferTypeSelector] entry, just with a lock icon
/// instead of a tap target.
class _LockedOfferTypeDisplay extends StatelessWidget {
  final String label;

  const _LockedOfferTypeDisplay({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed "today, or today+6 with the checkbox" validity display for
/// [OfferType.birthday] — replaces [_DateRangeRow]'s two tappable date
/// fields entirely, since this window is never picked by the owner
/// (per spec: "Etibarlılıq tarixi: bugün 00:00 – bugün 23:59 ...
/// dəyişdirilə bilməz"), only ever extended by the one checkbox.
class _BirthdayValidityDisplay extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final DateFormat dateFormat;
  final bool weekExtension;
  final ValueChanged<bool> onWeekExtensionChanged;

  const _BirthdayValidityDisplay({
    required this.startDate,
    required this.endDate,
    required this.dateFormat,
    required this.weekExtension,
    required this.onWeekExtensionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final rangeLabel = weekExtension ? '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}' : dateFormat.format(startDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.input)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 15, color: ChatLightColors.inkFaint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rangeLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          CheckboxListTile(
            value: weekExtension,
            onChanged: (v) => onWeekExtensionChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: Text(
              loc.offerBirthdayWeekExtensionLabel,
              style: const TextStyle(fontSize: 13.5, color: ChatLightColors.ink),
            ),
          ),
        ],
      ),
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

/// Start/end time-of-day pair for [OfferType.happyHour] — same
/// two-field row shape as [_DateRangeRow], just picking a daily
/// wall-clock time instead of a calendar date.
class _ActiveHoursRow extends StatelessWidget {
  final TimeOfDay start;
  final TimeOfDay end;
  final bool hasError;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _ActiveHoursRow({
    required this.start,
    required this.end,
    required this.hasError,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _TimeField(
            label: loc.offerActiveHoursStartLabel,
            time: start,
            hasError: hasError,
            onTap: onPickStart,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeField(
            label: loc.offerActiveHoursEndLabel,
            time: end,
            hasError: hasError,
            onTap: onPickEnd,
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final bool hasError;
  final VoidCallback onTap;

  const _TimeField({required this.label, required this.time, required this.hasError, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: hasError ? Border.all(color: AppColors.error) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint)),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatTimeOfDay(time),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                  ),
                ),
                Icon(Icons.access_time_outlined, size: 15, color: ChatLightColors.inkFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select weekday chips for [OfferType.happyHour]'s
/// `activeDays` — same chip visuals as [_OfferTypeSelector], reusing
/// the app's one existing set of short weekday labels
/// (`OpeningHoursEditor`'s own `_weekdayLabel`, duplicated here since
/// that helper is private to that file) so "B.e/Ç.a/Ç/..." never
/// drifts between the two screens.
class _ActiveDaysSelector extends StatelessWidget {
  final AppLocalizations loc;
  final Set<String> selectedDays;
  final ValueChanged<String> onToggle;

  const _ActiveDaysSelector({required this.loc, required this.selectedDays, required this.onToggle});

  String _labelFor(String day) => switch (day) {
    'mon' => loc.venueWeekdayMon,
    'tue' => loc.venueWeekdayTue,
    'wed' => loc.venueWeekdayWed,
    'thu' => loc.venueWeekdayThu,
    'fri' => loc.venueWeekdayFri,
    'sat' => loc.venueWeekdaySat,
    _ => loc.venueWeekdaySun,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in kAllWeekdayKeys)
          GestureDetector(
            onTap: () => onToggle(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selectedDays.contains(day) ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedDays.contains(day) ? AppColors.primary : ChatLightColors.inkFaint.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                _labelFor(day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selectedDays.contains(day) ? AppColors.primary : ChatLightColors.inkSoft,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Bu təklif pulsuzdur (qalıq: N/5)" / "Bu təklifin yerləşdirmə haqqı:
/// X AZN" — a client-side ESTIMATE from [venue]'s own founding/quota
/// fields (see [offerPlacementFeeForCategory]'s own doc comment); the
/// real eligibility check and charge happen server-side in
/// `submitOffer` at actual submit time, so this can drift by at most
/// the gap between picking a venue and pressing submit (e.g. the free
/// window expiring mid-form) — acceptable for a preview banner, not
/// something this reads as a guarantee.
class _PlacementFeeBanner extends StatelessWidget {
  final Venue venue;
  final AppLocalizations loc;

  const _PlacementFeeBanner({required this.venue, required this.loc});

  @override
  Widget build(BuildContext context) {
    final windowEnd = venue.freeOfferWindowEnd;
    final isFreeEligible =
        venue.isFoundingVenue && venue.freeOffersUsed < 5 && windowEnd != null && DateTime.now().isBefore(windowEnd);

    final String text;
    final IconData icon;
    final Color color;
    if (isFreeEligible) {
      text = loc.offerPlacementFreeNotice(5 - venue.freeOffersUsed);
      icon = Icons.card_giftcard_rounded;
      color = AppColors.primary;
    } else {
      text = loc.offerPlacementFeeNotice(offerPlacementFeeForCategory(venue.category).round());
      icon = Icons.payments_outlined;
      color = ChatLightColors.inkSoft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color))),
        ],
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
