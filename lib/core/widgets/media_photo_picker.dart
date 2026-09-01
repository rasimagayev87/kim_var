import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/chat/presentation/theme/chat_light_theme.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

import '../../core/widgets/pressable.dart';

/// Reusable "tap to add a photo" tile — shared by Create Venue, Create
/// Offer, Create Event, and PinBox, all of which also share
/// [PhotoPickerMixin] below for the pick/crop logic itself.
class MediaPhotoPicker extends StatelessWidget {
  final File? file;
  final String? existingUrl;
  final bool hasError;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const MediaPhotoPicker({
    super.key,
    required this.file,
    this.existingUrl,
    required this.hasError,
    required this.label,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasExisting = file == null && (existingUrl?.isNotEmpty ?? false);
    final hasAnyPhoto = file != null || hasExisting;

    return Pressable(
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
        child: !hasAnyPhoto
            ? Column(
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
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ChatLightColors.ink,
                    ),
                  ),
                ],
              )
            : file == null
            ? const SizedBox.shrink()
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Pressable(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Pick-from-gallery-or-camera → view original → crop (locked to the
/// caller's [aspectRatio], matching wherever the result is actually
/// displayed — see each call site) → deliver a [File]. The shared
/// "hardest part" of Create Venue/Offer/Event/PinBox's photo flow, iOS
/// lost-data recovery included. Mix into any `State<T> with
/// WidgetsBindingObserver` and call [checkLostPhotoOnResume] from
/// `didChangeAppLifecycleState`.
mixin PhotoPickerMixin<T extends StatefulWidget> on State<T> {
  /// The [aspectRatio] locked crop this delivers MUST match whatever
  /// fixed-size box the caller actually displays the result in
  /// (`BoxFit.cover`) — a free-form crop doesn't give the user a
  /// WYSIWYG result, it just moves the surprise to display time, where
  /// the exact same box re-crops whatever ratio they picked. Confirmed
  /// against every current display site: venue/offer/event covers all
  /// render in a fixed-height, full-width box (~16:9 on typical phone
  /// widths); PinBox always renders as a 1:1 square thumbnail.
  Future<void> pickPhoto(
    ValueChanged<File> onPicked, {
    required CropAspectRatio aspectRatio,
  }) async {
    final loc = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      loc.venuePhotoSheetTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ChatLightColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    loc.venuePhotoGalleryOption,
                    style: const TextStyle(
                      fontSize: 15,
                      color: ChatLightColors.ink,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    loc.venuePhotoCameraOption,
                    style: const TextStyle(
                      fontSize: 15,
                      color: ChatLightColors.ink,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    // Camera's native dismissal races the cropper's own presentation on
    // some devices — gallery doesn't hit this, same fix already used in
    // create_venue_screen.dart/create_offer_screen.dart's own pickers.
    if (source == ImageSource.camera)
      await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final proceed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _OriginalPhotoPreviewScreen(imagePath: picked.path),
        fullscreenDialog: true,
      ),
    );
    if (proceed != true || !mounted) return;

    await _cropAndDeliver(picked, onPicked, aspectRatio);
  }

  Future<void> checkLostPhotoOnResume(
    ValueChanged<File> onPicked, {
    required CropAspectRatio aspectRatio,
  }) async {
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.file == null || !mounted) return;
    await _cropAndDeliver(response.file!, onPicked, aspectRatio);
  }

  Future<void> _cropAndDeliver(
    XFile picked,
    ValueChanged<File> onPicked,
    CropAspectRatio aspectRatio,
  ) async {
    final loc = AppLocalizations.of(context);
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1600,
      maxHeight: 1600,
      aspectRatio: aspectRatio,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: loc.venuePhotoCropTitle,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: ChatLightColors.contourLine,
          activeControlsWidgetColor: AppColors.primary,
          backgroundColor: Colors.transparent,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: loc.venuePhotoCropTitle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (cropped != null && mounted) onPicked(File(cropped.path));
  }
}

/// Full-size, pinch-zoomable view of the JUST-PICKED original photo,
/// shown before the (aspect-ratio-locked) crop step — lets the user
/// see exactly what they're about to crop from, satisfying "view the
/// original before confirming" without needing to modify
/// `image_cropper`'s own native crop UI (a platform modal we can't
/// inject a custom button into).
class _OriginalPhotoPreviewScreen extends StatelessWidget {
  final String imagePath;

  const _OriginalPhotoPreviewScreen({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.file(File(imagePath)),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.photoPreviewContinueButton,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
