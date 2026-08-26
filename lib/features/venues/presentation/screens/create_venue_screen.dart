import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/payments/epoint_checkout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/media_photo_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/country_dial_code.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../domain/entities/venue.dart';
import '../../domain/venue_failure.dart';
import '../providers/venue_providers.dart';
import '../widgets/opening_hours_editor.dart';
import 'venue_location_picker_screen.dart';

/// Venues is a light-theme exception like the chat screens — every
/// color below comes from [ChatLightColors]/[AppColors.primary]
/// rather than the app's global dark [ThemeData], so widgets that
/// would otherwise inherit the dark theme (TextField, Switch,
/// ElevatedButton, bottom sheets) get their colors set explicitly.
class CreateVenueScreen extends ConsumerStatefulWidget {
  /// When set, the form opens pre-filled with this venue's data and
  /// submitting updates the existing document instead of creating a
  /// new one — same form, same validation, mirroring events' pattern.
  final Venue? existingVenue;

  const CreateVenueScreen({super.key, this.existingVenue});

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen>
    with WidgetsBindingObserver, PhotoPickerMixin<CreateVenueScreen> {
  static const _photoAspectRatio = CropAspectRatio(ratioX: 16, ratioY: 9);

  late final _nameController = TextEditingController(
    text: widget.existingVenue?.name ?? '',
  );
  late final _whatsappController = TextEditingController(
    text: widget.existingVenue?.socialLinks?.whatsapp ?? '',
  );
  late final _instagramController = TextEditingController(
    text: widget.existingVenue?.socialLinks?.instagram ?? '',
  );
  late final _tiktokController = TextEditingController(
    text: widget.existingVenue?.socialLinks?.tiktok ?? '',
  );

  bool get _isEditing => widget.existingVenue != null;

  late VenueCategory? _category = widget.existingVenue?.category;
  late LatLng? _pickedLatLng = widget.existingVenue != null
      ? LatLng(widget.existingVenue!.lat, widget.existingVenue!.lng)
      : null;
  late String _address = widget.existingVenue?.address ?? '';
  late String? _country = widget.existingVenue?.country;
  late OpeningHours _openingHours =
      widget.existingVenue?.openingHours ?? const OpeningHours();
  late DiscoverRadiusSelection _audienceRadius = _initialAudienceRadius();

  /// Only ever shown/editable when [_category] is in
  /// [kBirthdayEligibleVenueCategories] — every other category doesn't
  /// support this yet (see that constant's own doc comment), so this
  /// stays at its category-derived default and is never surfaced for
  /// them. Recomputed to the new category's default whenever the owner
  /// changes [_category] while creating (never on edit, where the
  /// stored value already reflects a real, possibly owner-overridden,
  /// choice).
  late bool _birthdayNotificationsEnabled =
      widget.existingVenue?.birthdayNotificationsEnabled ??
      (_category != null && kBirthdayEligibleVenueCategories.contains(_category));
  File? _photo;
  bool _submitting = false;
  Set<VenueFieldError> _fieldErrors = {};

  /// Non-null only while the photo is actively uploading (0.0–1.0) —
  /// drives the progress bar shown in place of the submit button's
  /// spinner. [_cancelUpload], set at the same time via
  /// `onUploadTaskReady`, is what the Cancel button in that state
  /// calls; the resulting failure surfaces through the normal
  /// `onError` path, and re-tapping "Əlavə et" is the retry — no
  /// separate retry plumbing needed.
  double? _uploadProgress;
  VoidCallback? _cancelUpload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  // A known iOS gap (see image_picker's own docs: "This check should
  // always be run ... to detect and handle this case"): the native
  // camera UI is memory-heavy enough that the OS can reclaim the
  // Flutter engine's state while it's on screen, silently losing the
  // in-flight `pickImage()` call's result — the exact "tapped Use
  // Photo, nothing happens" symptom. `retrieveLostData()` recovers
  // whatever was captured once the app resumes; checked on resume
  // (not just at cold start) since this screen usually stays mounted
  // across that memory reclaim, it just loses the pending Future.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkLostPhotoOnResume((file) => setState(() => _photo = file), aspectRatio: _photoAspectRatio);
    }
  }

  /// Trims each field and treats a blank result as "not provided" —
  /// null propagates all the way down to a Firestore write that omits
  /// (create) or clears (update) the field, instead of storing "".
  VenueSocialLinks? get _socialLinks {
    String? clean(String raw) => raw.trim().isEmpty ? null : raw.trim();
    final links = VenueSocialLinks(
      whatsapp: clean(_whatsappController.text),
      instagram: clean(_instagramController.text),
      tiktok: clean(_tiktokController.text),
    );
    return links.isEmpty ? null : links;
  }

  DiscoverRadiusSelection _initialAudienceRadius() {
    final existing = widget.existingVenue;
    if (existing == null) return const DiscoverRadiusSelection.distance(1.0);
    return switch (existing.audienceRadiusMode) {
      'country' => const DiscoverRadiusSelection.country(),
      'world' => const DiscoverRadiusSelection.world(),
      _ => DiscoverRadiusSelection.distance(existing.audienceRadiusKm),
    };
  }

  String get _audienceRadiusModeString => switch (_audienceRadius.mode) {
    DiscoverRadiusMode.distance => 'distance',
    DiscoverRadiusMode.country => 'country',
    DiscoverRadiusMode.world => 'world',
  };

  double get _audienceRadiusKmValue => _audienceRadius.km ?? 1.0;

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<(LatLng, String, String?)>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VenueLocationPickerScreen(initialPosition: _pickedLatLng),
      ),
    );
    if (result != null) {
      setState(() {
        _pickedLatLng = result.$1;
        _address = result.$2;
        _country = result.$3;
      });
    }
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<VenueCategory>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (_) => _CategoryPickerSheet(selected: _category),
    );
    if (selected != null) {
      setState(() {
        _category = selected;
        if (!_isEditing) {
          _birthdayNotificationsEnabled = kBirthdayEligibleVenueCategories.contains(selected);
        }
      });
    }
  }

  Future<void> _pickPhoto() =>
      pickPhoto((file) => setState(() => _photo = file), aspectRatio: _photoAspectRatio);

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

    final result = await ref
        .read(venueControllerProvider)
        .createVenue(
          name: _nameController.text,
          category: _category,
          photo: _photo,
          lat: _pickedLatLng?.latitude,
          lng: _pickedLatLng?.longitude,
          address: _address,
          country: _country,
          openingHours: _openingHours,
          socialLinks: _socialLinks,
          audienceRadiusMode: _audienceRadiusModeString,
          audienceRadiusKm: _audienceRadiusKmValue,
          birthdayNotificationsEnabled: _birthdayNotificationsEnabled,
          onValidationError: (missing) {
            if (!mounted) return;
            setState(() => _fieldErrors = missing.toSet());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.venueRequiredFieldsMissing)),
            );
          },
          onError: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.venueGenericErrorMessage)),
            );
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

    if (!mounted) return;
    await presentEpointCheckout(context, checkoutUrl: result.checkoutUrl, paymentId: result.paymentId, feeAmount: result.feeAmount);

    if (!mounted) return;
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

    final success = await ref
        .read(venueControllerProvider)
        .updateVenue(
          venueId: widget.existingVenue!.id,
          name: _nameController.text,
          category: _category,
          photo: _photo,
          hasExistingPhoto: widget.existingVenue?.photoUrl != null,
          lat: _pickedLatLng?.latitude,
          lng: _pickedLatLng?.longitude,
          address: _address,
          country: _country,
          openingHours: _openingHours,
          socialLinks: _socialLinks,
          audienceRadiusMode: _audienceRadiusModeString,
          audienceRadiusKm: _audienceRadiusKmValue,
          birthdayNotificationsEnabled: _birthdayNotificationsEnabled,
          onValidationError: (missing) {
            if (!mounted) return;
            setState(() => _fieldErrors = missing.toSet());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.venueRequiredFieldsMissing)),
            );
          },
          onError: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.venueGenericErrorMessage)),
            );
          },
          onUploadProgress: (p) {
            if (!mounted) return;
            setState(() => _uploadProgress = p);
          },
          onUploadTaskReady: (cancel) => _cancelUpload = cancel,
        );

    // A needs_revision OR already-approved venue moves back to pending
    // as a direct consequence of the owner editing it — no separate
    // "resubmit" step for them to remember, and no way for an owner to
    // silently swap in different content on a venue that already
    // cleared review (see `resubmitVenue`'s own doc comment).
    // Best-effort: the field edit above already succeeded either way,
    // so a resubmit failure here isn't surfaced as the whole save
    // failing, just silently left for the next edit (or a manual
    // retry) to move it back to pending.
    final wasLiveBeforeEdit = widget.existingVenue?.status == 'needs_revision' || widget.existingVenue?.status == 'approved';
    if (success && wasLiveBeforeEdit) {
      await ref
          .read(venueControllerProvider)
          .resubmitVenue(widget.existingVenue!.id);
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _uploadProgress = null;
      _cancelUpload = null;
    });

    if (success) {
      // Only the "was already approved, now back under review" case
      // gets a notice — needs_revision resubmission and a plain
      // pending-listing edit both already had no confirmation toast,
      // and shouldn't gain one just from this change.
      if (widget.existingVenue?.status == 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.venueSentForReReviewNotice)));
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: ChatLightColors.ink,
          ),
        ),
        title: Text(
          _isEditing ? loc.venueEditTitle : loc.venueCreateTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ChatLightColors.ink,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _VenuePhotoPicker(
                  file: _photo,
                  existingUrl: widget.existingVenue?.photoUrl,
                  hasError: _fieldErrors.contains(VenueFieldError.photo),
                  onPick: _pickPhoto,
                  onRemove: () => setState(() => _photo = null),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.venueNameLabel),
                _LightTextField(
                  controller: _nameController,
                  hint: loc.venueNameHint,
                  errorText: _fieldErrors.contains(VenueFieldError.name)
                      ? loc.venueFieldRequiredError
                      : null,
                  maxLength: 50,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.venueCategoryLabel),
                _CategoryField(
                  category: _category,
                  hasError: _fieldErrors.contains(VenueFieldError.category),
                  onTap: _pickCategory,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.venueHoursLabel),
                OpeningHoursEditor(
                  initial: _openingHours,
                  hasError: _fieldErrors.contains(VenueFieldError.hours),
                  onChanged: (hours) => _openingHours = hours,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FieldLabel(loc.venueLocationLabel),
                _LocationPickerField(
                  address: _address,
                  picked: _pickedLatLng != null,
                  hasError: _fieldErrors.contains(VenueFieldError.location),
                  onTap: _pickOnMap,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  loc.venueSocialSectionLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ChatLightColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _FieldLabel(loc.venueWhatsappLabel),
                _LightTextField(
                  controller: _whatsappController,
                  hint: loc.venueWhatsappHint,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                _FieldLabel(loc.venueInstagramLabel),
                _LightTextField(
                  controller: _instagramController,
                  hint: loc.venueInstagramHint,
                ),
                const SizedBox(height: AppSpacing.md),
                _FieldLabel(loc.venueTiktokLabel),
                _LightTextField(
                  controller: _tiktokController,
                  hint: loc.venueTiktokHint,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  loc.venueAudienceRadiusSectionLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ChatLightColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.venueAudienceRadiusHint,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ChatLightColors.inkSoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _AudienceRadiusSelector(
                  value: _audienceRadius,
                  country: _country,
                  onChanged: (selection) =>
                      setState(() => _audienceRadius = selection),
                ),
                if (_category != null &&
                    kBirthdayEligibleVenueCategories.contains(_category)) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _BirthdayNotificationsToggle(
                    value: _birthdayNotificationsEnabled,
                    onChanged: (v) =>
                        setState(() => _birthdayNotificationsEnabled = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                if (_submitting && _uploadProgress != null)
                  _UploadProgressCard(
                    progress: _uploadProgress!,
                    onCancel: _cancelUpload,
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                        foregroundColor: ChatLightColors.contourLine,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: ChatLightColors.contourLine,
                              ),
                            )
                          : Text(
                              _isEditing
                                  ? loc.venueSaveButton
                                  : loc.venueCreateButton,
                            ),
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

String venueCategoryLabel(AppLocalizations loc, VenueCategory category) {
  return switch (category) {
    VenueCategory.restaurant => loc.venueCategoryRestaurant,
    VenueCategory.pub => loc.venueCategoryPub,
    VenueCategory.coffeeShop => loc.venueCategoryCoffeeShop,
    VenueCategory.fastFood => loc.venueCategoryFastFood,
    VenueCategory.teaHouse => loc.venueCategoryTeaHouse,
    VenueCategory.sweetsShop => loc.venueCategorySweetsShop,
    VenueCategory.hotel => loc.venueCategoryHotel,
    VenueCategory.motel => loc.venueCategoryMotel,
    VenueCategory.cinema => loc.venueCategoryCinema,
    VenueCategory.karaoke => loc.venueCategoryKaraoke,
    VenueCategory.gameHall => loc.venueCategoryGameHall,
    VenueCategory.nightClub => loc.venueCategoryNightClub,
    VenueCategory.fitness => loc.venueCategoryFitness,
    VenueCategory.gym => loc.venueCategoryGym,
    VenueCategory.spa => loc.venueCategorySpa,
    VenueCategory.footballField => loc.venueCategoryFootballField,
    VenueCategory.clinic => loc.venueCategoryClinic,
    VenueCategory.beautySalon => loc.venueCategoryBeautySalon,
    VenueCategory.barbershop => loc.venueCategoryBarbershop,
    VenueCategory.cosmetology => loc.venueCategoryCosmetology,
    VenueCategory.tattoo => loc.venueCategoryTattoo,
    VenueCategory.photoStudio => loc.venueCategoryPhotoStudio,
    VenueCategory.kidsEntertainment => loc.venueCategoryKidsEntertainment,
    VenueCategory.pharmacyOptics => loc.venueCategoryPharmacyOptics,
    VenueCategory.dentalClinic => loc.venueCategoryDentalClinic,
    VenueCategory.perfumeryCosmetics => loc.venueCategoryPerfumeryCosmetics,
    VenueCategory.carWash => loc.venueCategoryCarWash,
    VenueCategory.carRepair => loc.venueCategoryCarRepair,
    VenueCategory.supermarket => loc.venueCategorySupermarket,
    VenueCategory.bookstoreStationery => loc.venueCategoryBookstoreStationery,
    VenueCategory.petStore => loc.venueCategoryPetStore,
    VenueCategory.tailor => loc.venueCategoryTailor,
    VenueCategory.dryCleaning => loc.venueCategoryDryCleaning,
    VenueCategory.applianceRepair => loc.venueCategoryApplianceRepair,
    VenueCategory.tutoringCenter => loc.venueCategoryTutoringCenter,
    VenueCategory.independentArtist => loc.venueCategoryIndependentArtist,
    VenueCategory.other => loc.venueCategoryOther,
  };
}

/// Same option set/UX shape as Discover's own radius picker
/// ([kDefaultRadiusOptionsKm] row + a "Daha çox" sheet with
/// [kExtraRadiusOptionsKm] plus Ölkə üzrə/Dünya üzrə) — the owner
/// picks how wide an area counts as their venue's "audience", using
/// the exact same rings/modes a viewer already knows from Discover,
/// just persisted per-venue instead of transient per-session. No
/// premium gating here unlike Discover's version — this is the venue
/// owner configuring their own venue, not a viewer's search radius.
String _audienceRadiusLabel(double km) => km < 1
    ? '${(km * 1000).round()} m'
    : '${km.toStringAsFixed(km % 1 == 0 ? 0 : 1)} km';

class _AudienceRadiusSelector extends StatelessWidget {
  final DiscoverRadiusSelection value;
  final String? country;
  final ValueChanged<DiscoverRadiusSelection> onChanged;

  const _AudienceRadiusSelector({
    required this.value,
    required this.country,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMoreSelected =
        value.mode != DiscoverRadiusMode.distance ||
        !kDefaultRadiusOptionsKm.contains(value.km);

    return Row(
      children: [
        for (var i = 0; i < kDefaultRadiusOptionsKm.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _AudienceRadiusChip(
              label: _audienceRadiusLabel(kDefaultRadiusOptionsKm[i]),
              selected:
                  value.mode == DiscoverRadiusMode.distance &&
                  value.km == kDefaultRadiusOptionsKm[i],
              onTap: () => onChanged(
                DiscoverRadiusSelection.distance(kDefaultRadiusOptionsKm[i]),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: _AudienceRadiusMoreChip(
            selected: isMoreSelected,
            onTap: () => _showMoreAudienceRadiusSheet(
              context,
              country: country,
              value: value,
              onSelected: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _AudienceRadiusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AudienceRadiusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : ChatLightColors.composerFill,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: selected ? null : Border.all(color: Colors.black12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected
                  ? ChatLightColors.contourLine
                  : ChatLightColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Same pill envelope as [_AudienceRadiusChip], styled as a neutral
/// trigger (highlighted only when the CURRENT selection lives inside
/// the sheet it opens — 5/10/30km or country/world — same "is one of
/// my hidden options active" convention as Discover's own more-button).
class _AudienceRadiusMoreChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AudienceRadiusMoreChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = selected ? ChatLightColors.contourLine : ChatLightColors.ink;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : ChatLightColors.composerFill,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: selected ? null : Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                loc.radiusMoreButtonLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_outlined, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

void _showMoreAudienceRadiusSheet(
  BuildContext context, {
  required String? country,
  required DiscoverRadiusSelection value,
  required ValueChanged<DiscoverRadiusSelection> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MoreAudienceRadiusPanel(
      country: country,
      value: value,
      onSelected: onSelected,
    ),
  );
}

class _MoreAudienceRadiusPanel extends StatelessWidget {
  final String? country;
  final DiscoverRadiusSelection value;
  final ValueChanged<DiscoverRadiusSelection> onSelected;

  const _MoreAudienceRadiusPanel({
    required this.country,
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final countryFlag = flagForCountryName(country);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              loc.radiusMorePanelTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ChatLightColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < kExtraRadiusOptionsKm.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _AudienceRadiusChip(
                      label: _audienceRadiusLabel(kExtraRadiusOptionsKm[i]),
                      selected:
                          value.mode == DiscoverRadiusMode.distance &&
                          value.km == kExtraRadiusOptionsKm[i],
                      onTap: () {
                        onSelected(
                          DiscoverRadiusSelection.distance(
                            kExtraRadiusOptionsKm[i],
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SpecialAudienceRadiusOption(
                    icon: countryFlag == null ? Icons.flag_outlined : null,
                    flag: countryFlag,
                    label: loc.privacyRadiusCountryLabel,
                    selected: value.mode == DiscoverRadiusMode.country,
                    onTap: () {
                      onSelected(const DiscoverRadiusSelection.country());
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SpecialAudienceRadiusOption(
                    icon: Icons.public_outlined,
                    flag: null,
                    label: loc.privacyRadiusWorldLabel,
                    selected: value.mode == DiscoverRadiusMode.world,
                    onTap: () {
                      onSelected(const DiscoverRadiusSelection.world());
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Same pill envelope as [_AudienceRadiusChip] — a flag/globe icon plus
/// a short label instead of a distance value, backing the Ölkə üzrə/
/// Dünya üzrə options.
class _SpecialAudienceRadiusOption extends StatelessWidget {
  final IconData? icon;
  final String? flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpecialAudienceRadiusOption({
    required this.icon,
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? ChatLightColors.contourLine : ChatLightColors.ink;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : ChatLightColors.composerFill,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: selected ? null : Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null)
              Text(flag!, style: const TextStyle(fontSize: 20))
            else
              Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Only ever rendered when `_category` is in
/// `kBirthdayEligibleVenueCategories` — see that constant's doc
/// comment for why every other category doesn't get this at all yet.
class _BirthdayNotificationsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BirthdayNotificationsToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.input)),
      child: Row(
        children: [
          const Icon(Icons.cake_outlined, size: 20, color: ChatLightColors.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.venueBirthdayNotificationsTitle,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.venueBirthdayNotificationsHint,
                  style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
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
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: ChatLightColors.ink,
        ),
      ),
    );
  }
}

/// Plain white rounded field — the app's global [TextField] theme is
/// dark, so every visual is set explicitly rather than inherited.
/// `filled: false` and every `*Border` property below are required,
/// not cosmetic: the global `InputDecorationTheme` sets `filled: true`
/// with a dark `fillColor` (`AppColors.card`) and its own dark
/// `enabledBorder`/`focusedBorder`/`errorBorder`. Setting only the
/// generic `border:` on this widget's own [InputDecoration] does NOT
/// override those — Flutter falls back to the theme's more specific
/// border properties whenever a widget doesn't set that exact same
/// property itself, `border:` is only used when none of the specific
/// ones are set anywhere. The outer [Container] already draws this
/// field's real (light) border/background, so the [TextField] itself
/// must render as fully bare — no fill, no border of its own at all.
class _LightTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final int? maxLength;
  final TextInputType? keyboardType;

  const _LightTextField({
    required this.controller,
    required this.hint,
    this.errorText,
    this.maxLength,
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
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : ChatLightColors.inkFaint.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLength: maxLength,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: ChatLightColors.ink,
                  ),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: ChatLightColors.inkFaint,
                      fontWeight: FontWeight.w400,
                      fontSize: 15.5,
                    ),
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
              if (maxLength != null)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => Text(
                    '${value.text.length}/$maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: ChatLightColors.inkSoft,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  final VenueCategory? category;
  final bool hasError;
  final VoidCallback onTap;

  const _CategoryField({
    required this.category,
    required this.hasError,
    required this.onTap,
  });

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
              border: hasError
                  ? Border.all(color: AppColors.error, width: 1.2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category != null
                        ? venueCategoryIcon(category!)
                        : Icons.category_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category != null
                            ? venueCategoryLabel(loc, category!)
                            : loc.venueCategoryUnselectedLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ChatLightColors.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        loc.venueCategoryChangeHint,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ChatLightColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: ChatLightColors.inkFaint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            loc.venueFieldRequiredError,
            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

/// BottomSheet category picker — search field + a flat, filterable
/// list of every [VenueCategory] (icon + label). Not grouped into
/// sections — a single scrollable list already satisfies "expandable"
/// without the extra complexity of accordion groups for ~18 items.
class _CategoryPickerSheet extends StatefulWidget {
  final VenueCategory? selected;

  const _CategoryPickerSheet({required this.selected});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final categories = VenueCategory.values
        .where(
          (c) =>
              query.isEmpty ||
              venueCategoryLabel(loc, c).toLowerCase().contains(query),
        )
        .toList();

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SafeArea(
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
                decoration: BoxDecoration(
                  color: ChatLightColors.inkFaint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              loc.venueCategoryPickerTitle,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: ChatLightColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(
                  color: ChatLightColors.inkFaint.withValues(alpha: 0.18),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: ChatLightColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      autofocus: false,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: ChatLightColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: loc.venueCategorySearchHint,
                        hintStyle: TextStyle(
                          color: ChatLightColors.inkFaint,
                          fontSize: 14.5,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.14)
                                    : ChatLightColors.cardSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                venueCategoryIcon(category),
                                size: 18,
                                color: isSelected
                                    ? AppColors.primary
                                    : ChatLightColors.ink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                venueCategoryLabel(loc, category),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: ChatLightColors.ink,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: AppColors.primary,
                              ),
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
      ),
    );
  }
}

class _LocationPickerField extends StatelessWidget {
  final String address;
  final bool picked;
  final bool hasError;
  final VoidCallback onTap;

  const _LocationPickerField({
    required this.address,
    required this.picked,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: hasError
              ? Border.all(color: AppColors.error, width: 1.2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: picked
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : ChatLightColors.cardSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                picked ? Icons.check_circle_outline : Icons.map_outlined,
                size: 20,
                color: picked ? AppColors.primary : ChatLightColors.inkSoft,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    picked
                        ? loc.venueLocationPickedLabel
                        : loc.venuePickOnMapButton,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: ChatLightColors.ink,
                    ),
                  ),
                  if (picked && address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ChatLightColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: ChatLightColors.inkFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the submit button while a photo upload is in flight — a
/// real percentage (from Firebase Storage's `snapshotEvents`, not a
/// simulated timer) plus a Cancel action that aborts the underlying
/// `UploadTask`. On cancel the write fails like any other upload
/// error, and re-tapping "Əlavə et" naturally retries from scratch.
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.venueUploadingLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ChatLightColors.ink,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              child: Text(loc.venueUploadCancelButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _VenuePhotoPicker extends StatelessWidget {
  final File? file;
  final String? existingUrl;
  final bool hasError;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _VenuePhotoPicker({
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
            color: hasError
                ? AppColors.error
                : ChatLightColors.inkFaint.withValues(alpha: 0.35),
            width: hasError ? 1.2 : 1.4,
          ),
          image: file != null
              ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
              : hasExisting
              ? DecorationImage(
                  image: NetworkImage(existingUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: !hasAnyPhoto ? _buildPlaceholder(loc) : _buildRemoveButton(),
      ),
    );
  }

  Widget _buildPlaceholder(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          loc.venuePhotoLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ChatLightColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    if (file == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}
