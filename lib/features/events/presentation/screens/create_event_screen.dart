import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/entities/venue_event.dart';
import '../providers/venue_event_providers.dart';
import 'category_label.dart';

const _kDescriptionMaxLength = 300;

/// Owner-only "Tədbir yarat" form, reached from `MyVenuesScreen`'s
/// 3-dot menu → "Tədbirlər" list's "+" button. No draft/pending state —
/// "Yayımla" writes straight to Firestore as `upcoming` and the
/// `notifyNearbyUsersOfNewEvent` Cloud Function fires immediately (see
/// `VenueEvent`'s doc comment for why events skip the venue/offer
/// moderation gate entirely).
///
/// When [existingEvent] is set, this is the SAME form reused for
/// "Düzəliş et" (edit) instead — same fields, same validation, only
/// [venue] identity/geo fields aren't editable (an event can't move to
/// a different venue) and the submit path calls
/// [VenueEventController.updateEvent] instead of `createEvent`. Only
/// ever reachable for an `upcoming`/`live` event — see `_EventCard`'s
/// own `canEdit` gate.
class CreateEventScreen extends ConsumerStatefulWidget {
  final Venue venue;
  final VenueEvent? existingEvent;

  const CreateEventScreen({super.key, required this.venue, this.existingEvent});

  bool get _isEditing => existingEvent != null;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> with WidgetsBindingObserver {
  late final _titleController = TextEditingController(text: widget.existingEvent?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existingEvent?.description ?? '');
  File? _coverImage;
  late VenueEventCategory _category = widget.existingEvent?.category ?? VenueEventCategory.music;
  late DateTime? _startAt = widget.existingEvent?.startAt;
  late DateTime? _endAt = widget.existingEvent?.endAt;
  bool _submitting = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // See the identical comment in create_venue_screen.dart's own
  // `didChangeAppLifecycleState` — same iOS camera-memory-reclaim gap,
  // same recovery via image_picker's documented `retrieveLostData()`.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLostCoverImage();
  }

  Future<void> _checkLostCoverImage() async {
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.file == null || !mounted) return;
    await _cropAndSetCover(response.file!);
  }

  Future<void> _pickCoverImage() async {
    final loc = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text(loc.venuePhotoGalleryOption),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: Text(loc.venuePhotoCameraOption),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;
    await _cropAndSetCover(picked);
  }

  Future<void> _cropAndSetCover(XFile picked) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1600,
      maxHeight: 1200,
      aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(toolbarColor: AppColors.primary, activeControlsWidgetColor: AppColors.primary),
        IOSUiSettings(aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return;
    setState(() => _coverImage = File(cropped.path));
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final current = (isStart ? _startAt : _endAt) ?? (isStart ? now : (_startAt ?? now));
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: isStart ? now.subtract(const Duration(days: 1)) : (_startAt ?? now),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _startAt != null &&
      _endAt != null &&
      _endAt!.isAfter(_startAt!);

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    final loc = AppLocalizations.of(context);

    final bool ok;
    if (widget._isEditing) {
      ok = await ref.read(venueEventControllerProvider).updateEvent(
            eventId: widget.existingEvent!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            coverImage: _coverImage,
            startAt: _startAt!,
            endAt: _endAt!,
            category: _category,
            onUploadProgress: (p) => setState(() => _uploadProgress = p),
          );
    } else {
      final id = await ref.read(venueEventControllerProvider).createEvent(
            venueId: widget.venue.id,
            venueName: widget.venue.name,
            venuePhotoUrl: widget.venue.photoUrl,
            lat: widget.venue.lat,
            lng: widget.venue.lng,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            coverImage: _coverImage,
            startAt: _startAt!,
            endAt: _endAt!,
            category: _category,
            onUploadProgress: (p) => setState(() => _uploadProgress = p),
          );
      ok = id != null;
    }

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _submitting = false;
        _uploadProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.venueGenericErrorMessage)));
    }
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
          widget._isEditing ? loc.eventEditTitle : loc.eventCreateTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: ChatLightColors.inkFaint.withValues(alpha: 0.18)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _coverImage != null
                    ? Image.file(_coverImage!, fit: BoxFit.cover)
                    : widget.existingEvent?.coverImageUrl != null
                    ? Image.network(widget.existingEvent!.coverImageUrl!, fit: BoxFit.cover)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 32, color: ChatLightColors.inkFaint),
                            const SizedBox(height: 8),
                            Text(loc.eventCoverImageLabel, style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 13)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            _FieldLabel(loc.eventTitleLabel),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 15.5, color: ChatLightColors.ink),
              decoration: InputDecoration(hintText: loc.eventTitleHint, filled: true, fillColor: Colors.white),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            _FieldLabel(loc.eventDescriptionLabel),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: _kDescriptionMaxLength,
              style: const TextStyle(fontSize: 15.5, color: ChatLightColors.ink),
              decoration: InputDecoration(hintText: loc.eventDescriptionHint, filled: true, fillColor: Colors.white),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            _FieldLabel(loc.eventCategoryLabel),
            DropdownButtonFormField<VenueEventCategory>(
              initialValue: _category,
              decoration: const InputDecoration(filled: true, fillColor: Colors.white),
              items: VenueEventCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(eventCategoryLabel(loc, c))))
                  .toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 18),
            _FieldLabel(loc.eventStartLabel),
            _DateTimeRow(value: _startAt, onTap: () => _pickDateTime(isStart: true), formatter: _formatDateTime),
            const SizedBox(height: 18),
            _FieldLabel(loc.eventEndLabel),
            _DateTimeRow(value: _endAt, onTap: () => _pickDateTime(isStart: false), formatter: _formatDateTime),
            const SizedBox(height: 28),
            if (_uploadProgress != null) ...[
              LinearProgressIndicator(value: _uploadProgress, color: AppColors.primary),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: (_canSubmit && !_submitting) ? _submit : null,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                  : Text(widget._isEditing ? loc.venueSaveButton : loc.eventPublishButton),
            ),
          ],
        ),
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

class _DateTimeRow extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final String Function(DateTime) formatter;

  const _DateTimeRow({required this.value, required this.onTap, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.input),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: ChatLightColors.inkFaint.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              value != null ? formatter(value!) : loc.eventDateTimePlaceholder,
              style: TextStyle(fontSize: 15, color: value != null ? ChatLightColors.ink : ChatLightColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
