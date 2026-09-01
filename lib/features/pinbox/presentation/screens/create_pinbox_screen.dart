import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/media_photo_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/domain/venue_listing_eligibility.dart';
import '../../../venues/presentation/venue_block_message.dart';
import '../../domain/entities/pinbox.dart';
import '../../domain/pinbox_failure.dart';
import '../providers/pinbox_providers.dart';

String _formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// PinBox Faza 5 — "PinBox yarat", also doubling as the edit form
/// (Qutularım → Yaratdıqlarım's 3-dot menu) when [existingPinBox] is
/// passed — same "one screen, `existingX` param" convention as
/// `CreateOfferScreen`/`CreateVenueScreen`. Always venue-scoped: on
/// create, the caller (Kəşf et → Fürsətlər's "+" chooser, see
/// `discover_tab.dart`'s `_openCreateOptionsSheet`) already resolved
/// (or asked the owner to pick) an eligible venue before pushing here,
/// so there's no venue picker inside this form — and on edit, the venue
/// link is fixed anyway (see `PinBoxRepository.updatePinBox`'s doc
/// comment), so [venue] is only ever needed for the create path.
class CreatePinBoxScreen extends ConsumerStatefulWidget {
  /// Required to create; unused (and safely omittable) when editing —
  /// see this class's own doc comment.
  final Venue? venue;
  final PinBox? existingPinBox;

  const CreatePinBoxScreen({super.key, this.venue, this.existingPinBox}) : assert(venue != null || existingPinBox != null);

  @override
  ConsumerState<CreatePinBoxScreen> createState() => _CreatePinBoxScreenState();
}

class _CreatePinBoxScreenState extends ConsumerState<CreatePinBoxScreen>
    with WidgetsBindingObserver, PhotoPickerMixin<CreatePinBoxScreen> {
  late final _titleController = TextEditingController(text: widget.existingPinBox?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existingPinBox?.description ?? '');
  late final _originalPriceController =
      TextEditingController(text: widget.existingPinBox?.originalPrice.toStringAsFixed(2) ?? '');
  late final _pinboxPriceController =
      TextEditingController(text: widget.existingPinBox?.pinboxPrice.toStringAsFixed(2) ?? '');
  late final _stockController = TextEditingController(text: widget.existingPinBox?.stockTotal.toString() ?? '');

  bool get _isEditing => widget.existingPinBox != null;

  File? _photo;
  late TimeOfDay? _pickupStart =
      widget.existingPinBox != null ? TimeOfDay.fromDateTime(widget.existingPinBox!.pickupWindowStart) : null;
  late TimeOfDay? _pickupEnd =
      widget.existingPinBox != null ? TimeOfDay.fromDateTime(widget.existingPinBox!.pickupWindowEnd) : null;
  Set<PinBoxFieldError> _fieldErrors = {};
  bool _submitting = false;
  double? _uploadProgress;
  VoidCallback? _cancelUpload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Live-recompute the discount badge as either price field changes.
    _originalPriceController.addListener(_onPriceChanged);
    _pinboxPriceController.addListener(_onPriceChanged);
  }

  void _onPriceChanged() => setState(() {});

  // Same iOS camera-memory-reclaim gap as Create Venue/Offer's own
  // `didChangeAppLifecycleState` — see `PhotoPickerMixin`'s doc comment.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkLostPhotoOnResume(
        (file) => setState(() => _photo = file),
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _descriptionController.dispose();
    _originalPriceController.dispose();
    _pinboxPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickPickupTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _pickupStart : _pickupEnd) ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _pickupStart = picked;
      } else {
        _pickupEnd = picked;
      }
    });
  }

  /// Today's date + the picked wall-clock time — PinBox pickup windows
  /// are always same-day (perishable/quick-turnover goods), per the
  /// product spec's own mockups (a time-only picker, no date field).
  DateTime? _resolvedDateTime(TimeOfDay? time) {
    if (time == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  double? get _originalPrice => double.tryParse(_originalPriceController.text.replaceAll(',', '.'));

  double? get _pinboxPrice => double.tryParse(_pinboxPriceController.text.replaceAll(',', '.'));

  int? get _stockTotal => int.tryParse(_stockController.text);

  int? get _discountPercent {
    final original = _originalPrice;
    final pinbox = _pinboxPrice;
    if (original == null || pinbox == null || original <= 0 || pinbox >= original) return null;
    return (((original - pinbox) / original) * 100).round();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_isEditing) {
      await _submitEdit();
    } else {
      await _submitCreate();
    }
  }

  Future<void> _submitCreate() async {
    // See `CreateOfferScreen._submitCreate` for why this is re-checked
    // at submit and not only where the venue was chosen: a form takes
    // minutes, and a subscription can lapse inside them. `venueIsLive()`
    // in `firestore.rules` still does the enforcing; this only turns its
    // `permission-denied` into a sentence that says what to do.
    final blockCheck = venueListingBlock(widget.venue!.status);
    if (blockCheck != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(venueBlockMessage(AppLocalizations.of(context), blockCheck))),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _fieldErrors = {};
      _uploadProgress = _photo != null ? 0 : null;
      _cancelUpload = null;
    });

    final loc = AppLocalizations.of(context);
    final venue = widget.venue!;

    final pinboxId = await ref.read(pinboxControllerProvider).createPinBox(
          venueId: venue.id,
          venueName: venue.name,
          venuePhotoUrl: venue.photoUrl,
          lat: venue.lat,
          lng: venue.lng,
          address: venue.address,
          country: venue.country,
          category: venue.category,
          title: _titleController.text,
          description: _descriptionController.text,
          photo: _photo,
          originalPrice: _originalPrice,
          pinboxPrice: _pinboxPrice,
          stockTotal: _stockTotal,
          pickupWindowStart: _resolvedDateTime(_pickupStart),
          pickupWindowEnd: _resolvedDateTime(_pickupEnd),
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

    if (pinboxId != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.pinboxCreatedNotice)));
      Navigator.pop(context);
    }
  }

  Future<void> _submitEdit() async {
    setState(() {
      _submitting = true;
      _fieldErrors = {};
      _uploadProgress = _photo != null ? 0 : null;
      _cancelUpload = null;
    });

    final loc = AppLocalizations.of(context);

    // The `updatePinBox` Cloud Function decides atomically, server-side,
    // whether this edit needs to re-enter moderation — same reasoning
    // as CreateVenueScreen._submitEdit, just without the separate
    // client-side `resubmitPinBox` call this used to need (see that
    // Cloud Function's own doc comment, functions/src/index.ts).
    final (:success, :sentForReReview) = await ref.read(pinboxControllerProvider).updatePinBox(
          pinboxId: widget.existingPinBox!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          photo: _photo,
          hasExistingPhoto: widget.existingPinBox!.imageUrl != null,
          originalPrice: _originalPrice,
          pinboxPrice: _pinboxPrice,
          pickupWindowStart: _resolvedDateTime(_pickupStart),
          pickupWindowEnd: _resolvedDateTime(_pickupEnd),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sentForReReview ? loc.pinboxSentForReReviewNotice : loc.pinboxUpdatedNotice)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final discountPercent = _discountPercent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        title: Text(
          _isEditing ? loc.pinboxEditTitle : loc.createPinboxMenuOption,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                MediaPhotoPicker(
                  file: _photo,
                  existingUrl: widget.existingPinBox?.imageUrl,
                  hasError: _fieldErrors.contains(PinBoxFieldError.photo),
                  label: loc.pinboxPhotoLabel,
                  onPick: () => pickPhoto(
                    (file) => setState(() => _photo = file),
                    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                  ),
                  onRemove: () => setState(() => _photo = null),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.pinboxNameLabel),
                _LightTextField(
                  controller: _titleController,
                  hint: loc.pinboxNameHint,
                  maxLength: 50,
                  errorText: _fieldErrors.contains(PinBoxFieldError.title) ? loc.venueFieldRequiredError : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.pinboxDescriptionLabel),
                _LightTextField(
                  controller: _descriptionController,
                  hint: loc.pinboxDescriptionHint,
                  maxLength: 200,
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(loc.pinboxOriginalPriceLabel),
                          _LightTextField(
                            controller: _originalPriceController,
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            errorText: _fieldErrors.contains(PinBoxFieldError.price) ? loc.venueFieldRequiredError : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _FieldLabel(loc.pinboxPriceLabel),
                              if (discountPercent != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '-$discountPercent%',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          _LightTextField(
                            controller: _pinboxPriceController,
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            errorText: _fieldErrors.contains(PinBoxFieldError.price) ? loc.venueFieldRequiredError : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_isEditing) ...[
                  // Total stock is create-time-only — `stockRemaining` is
                  // locked from every client update (see
                  // `PinBoxRepository.updatePinBox`'s doc comment), so
                  // changing the total here without a matching Cloud
                  // Function to reconcile it would desync the two. Shown
                  // read-only instead of hidden outright, so the owner
                  // isn't left wondering where it went.
                  _FieldLabel(loc.pinboxStockLabel),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: ChatLightColors.cardSurface,
                      borderRadius: BorderRadius.circular(AppRadii.input),
                    ),
                    child: Text(
                      loc.pinboxStockLockedNote(widget.existingPinBox!.stockRemaining, widget.existingPinBox!.stockTotal),
                      style: const TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft),
                    ),
                  ),
                ] else ...[
                  _FieldLabel(loc.pinboxStockLabel),
                  _LightTextField(
                    controller: _stockController,
                    hint: loc.pinboxStockHint,
                    keyboardType: TextInputType.number,
                    errorText: _fieldErrors.contains(PinBoxFieldError.stock) ? loc.venueFieldRequiredError : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.pinboxPickupWindowLabel),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: loc.pinboxPickupStartLabel,
                        time: _pickupStart,
                        hasError: _fieldErrors.contains(PinBoxFieldError.pickupWindow),
                        onTap: () => _pickPickupTime(isStart: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TimeField(
                        label: loc.pinboxPickupEndLabel,
                        time: _pickupEnd,
                        hasError: _fieldErrors.contains(PinBoxFieldError.pickupWindow),
                        onTap: () => _pickPickupTime(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                // "Ödəniş edildikdən sonra sifariş ləğv edilə bilməz" is
                // enforced at Checkout (PinBox Faza 7) — surfaced here
                // too so the owner understands the box's own contract
                // before publishing it.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loc.pinboxNonRefundableNotice,
                          style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                if (_submitting && _uploadProgress != null)
                  _PinBoxUploadProgressCard(progress: _uploadProgress!, onCancel: _cancelUpload)
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
                          : Text(_isEditing ? loc.venueSaveButton : loc.pinboxPublishButton),
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

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
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
                    time != null ? _formatTimeOfDay(time!) : '--:--',
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

class _PinBoxUploadProgressCard extends StatelessWidget {
  final double progress;
  final VoidCallback? onCancel;

  const _PinBoxUploadProgressCard({required this.progress, required this.onCancel});

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
