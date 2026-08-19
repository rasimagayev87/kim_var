import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/chat/presentation/theme/chat_light_theme.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Reusable "tap to add a photo" tile — extracted from Create Venue's
/// and Create Offer's own near-identical private picker widgets so a
/// 3rd near-duplicate (PinBox, Faza 5) doesn't repeat it a 4th time.
/// Venue/Offer keep their own existing private widgets untouched (no
/// risk to already-working screens); only new screens need to reach
/// for this one.
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
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
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

/// Pick-from-gallery-or-camera → crop → deliver a [File] — the shared
/// "hardest part" of Create Venue/Offer/PinBox's photo flow, iOS
/// lost-data recovery included. Mix into any `State<T> with
/// WidgetsBindingObserver` and call [checkLostPhotoOnResume] from
/// `didChangeAppLifecycleState`.
mixin PhotoPickerMixin<T extends StatefulWidget> on State<T> {
  Future<void> pickPhoto(ValueChanged<File> onPicked) async {
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
    // Camera's native dismissal races the cropper's own presentation on
    // some devices — gallery doesn't hit this, same fix already used in
    // create_venue_screen.dart/create_offer_screen.dart's own pickers.
    if (source == ImageSource.camera) await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _cropAndDeliver(picked, onPicked);
  }

  Future<void> checkLostPhotoOnResume(ValueChanged<File> onPicked) async {
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.file == null || !mounted) return;
    await _cropAndDeliver(response.file!, onPicked);
  }

  Future<void> _cropAndDeliver(XFile picked, ValueChanged<File> onPicked) async {
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
    if (cropped != null && mounted) onPicked(File(cropped.path));
  }
}
