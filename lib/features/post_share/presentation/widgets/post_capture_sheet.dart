import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/post.dart';
import '../screens/post_preview_screen.dart';

enum _PostCaptureOption { camera, galleryPhoto, galleryVideo }

/// Entry point for the repurposed "+" nav button: choose a source →
/// pick/capture → push [PostPreviewScreen]. Mirrors the same
/// sheet/pick/preview shape as `startCreateStoryFlow` (stories
/// feature) for visual and behavioral consistency. Returns true once
/// the user actually shares a post, so the caller can switch to the
/// Profile tab to show it — false for every cancel/back path.
Future<bool> startCreatePostFlow(BuildContext context) async {
  final loc = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<_PostCaptureOption>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(loc.postCaptureSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary),
              title: Text(loc.postCameraOption, style: AppTextStyles.body.copyWith(fontSize: 15)),
              onTap: () => Navigator.pop(sheetContext, _PostCaptureOption.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
              title: Text(loc.postGalleryPhotoOption, style: AppTextStyles.body.copyWith(fontSize: 15)),
              onTap: () => Navigator.pop(sheetContext, _PostCaptureOption.galleryPhoto),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: AppColors.textSecondary),
              title: Text(loc.postGalleryVideoOption, style: AppTextStyles.body.copyWith(fontSize: 15)),
              onTap: () => Navigator.pop(sheetContext, _PostCaptureOption.galleryVideo),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return false;

  final picker = ImagePicker();
  final PostMediaType mediaType = choice == _PostCaptureOption.galleryVideo ? PostMediaType.video : PostMediaType.photo;

  final XFile? picked = switch (choice) {
    _PostCaptureOption.camera => await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85),
    _PostCaptureOption.galleryPhoto => await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85),
    _PostCaptureOption.galleryVideo => await picker.pickVideo(source: ImageSource.gallery),
  };
  if (picked == null || !context.mounted) return false;

  final shared = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => PostPreviewScreen(file: File(picked.path), mediaType: mediaType)),
  );
  return shared ?? false;
}
