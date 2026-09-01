import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/media_photo_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/domain/venue_listing_eligibility.dart';
import '../../../venues/presentation/venue_block_message.dart';
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

class _CreateEventScreenState extends ConsumerState<CreateEventScreen>
    with WidgetsBindingObserver, PhotoPickerMixin<CreateEventScreen> {
  // 16:9 — matches `event_details_screen.dart`'s fixed-height cover
  // box (not the old 4:3 this replaces, which is what caused a
  // portrait poster to lose most of its height right at upload time).
  static const _coverAspectRatio = CropAspectRatio(ratioX: 16, ratioY: 9);

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
    if (state == AppLifecycleState.resumed) {
      checkLostPhotoOnResume((file) => setState(() => _coverImage = file), aspectRatio: _coverAspectRatio);
    }
  }

  Future<void> _pickCoverImage() =>
      pickPhoto((file) => setState(() => _coverImage = file), aspectRatio: _coverAspectRatio);

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

    // Only on create. Editing an existing event must stay possible even
    // if the venue's status has since changed — the event is already
    // live, and blocking its edit would strand the owner with content
    // they cannot correct.
    if (!widget._isEditing) {
      final block = venueListingBlock(widget.venue.status);
      if (block != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(venueBlockMessage(AppLocalizations.of(context), block))),
        );
        return;
      }
    }

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
            venueCategory: widget.venue.category,
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
                    ? AppImage(widget.existingEvent!.coverImageUrl!, fit: BoxFit.cover)
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
            // The period's event allowance. Creating (not editing) is
            // the only case it applies to — an edit publishes nothing
            // new and spends nothing.
            if (!widget._isEditing) ...[
              _EventQuotaBanner(venue: widget.venue, loc: loc),
              const SizedBox(height: 16),
            ],
            if (_uploadProgress != null) ...[
              LinearProgressIndicator(value: _uploadProgress, color: AppColors.primary),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: (_canSubmit && !_submitting && (widget._isEditing || _eventQuotaLeft(widget.venue) > 0))
                  ? _submit
                  : null,
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

/// Events a venue may still publish this subscription period.
///
/// A PREVIEW of `FREE_EVENTS_PER_PERIOD` and the counter
/// `onVenueEventCreated` actually spends — the server decides, in a
/// transaction, and rejects the event with a notification if this was
/// stale. Blocking the button here is a courtesy, not the boundary.
///
/// Zero while the subscription is unpaid, mirroring
/// `currentSubscriptionPeriodStart`: no period means no allowance, and
/// the counter freezes rather than resetting.
int _eventQuotaLeft(Venue venue) {
  final renewsAt = venue.subscriptionRenewsAt;
  if (renewsAt == null || !DateTime.now().isBefore(renewsAt)) return 0;
  return (kFreeEventsPerPeriod - venue.freeEventsUsed).clamp(0, kFreeEventsPerPeriod);
}

class _EventQuotaBanner extends StatelessWidget {
  const _EventQuotaBanner({required this.venue, required this.loc});

  final Venue venue;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final left = _eventQuotaLeft(venue);
    final renewsAt = venue.subscriptionRenewsAt;
    final date = renewsAt == null
        ? '—'
        : '${renewsAt.day.toString().padLeft(2, '0')}.${renewsAt.month.toString().padLeft(2, '0')}.${renewsAt.year}';
    final exhausted = left == 0;
    final color = exhausted ? AppColors.error : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(exhausted ? Icons.block : Icons.event_available_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // Unlike a campaign, there is no paid path to offer here —
              // so the message says when the allowance returns instead
              // of what it would cost.
              exhausted
                  ? loc.eventQuotaExhausted(kFreeEventsPerPeriod, date)
                  : loc.eventQuotaRemaining(left, kFreeEventsPerPeriod),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
