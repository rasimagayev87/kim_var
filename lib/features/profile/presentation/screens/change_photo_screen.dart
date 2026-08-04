import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/photo_upload_provider.dart';
import '../providers/profile_providers.dart';
import '../storage_failure_messages.dart';

/// Settings → "Profil şəklini dəyiş" — split out of the old combined
/// edit-profile screen, which no longer has a photo section (the new
/// "Şəxsi məlumatlar" screen matches an exact 8-field design spec
/// with no room for an avatar picker).
class ChangePhotoScreen extends ConsumerStatefulWidget {
  const ChangePhotoScreen({super.key});

  @override
  ConsumerState<ChangePhotoScreen> createState() => _ChangePhotoScreenState();
}

class _ChangePhotoScreenState extends ConsumerState<ChangePhotoScreen> {
  File? _pickedPhotoFile;
  bool _photoRemoved = false;

  Future<void> _pickPhoto() async {
    if (ref.read(photoUploadControllerProvider).isLoading) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _pickedPhotoFile = file;
      _photoRemoved = false;
    });
    await ref.read(photoUploadControllerProvider.notifier).upload(file);
  }

  Future<void> _removePhoto() async {
    if (ref.read(photoUploadControllerProvider).isLoading) return;

    setState(() {
      _pickedPhotoFile = null;
      _photoRemoved = true;
    });
    await ref.read(photoUploadControllerProvider.notifier).remove();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final photoUploadState = ref.watch(photoUploadControllerProvider);
    final profilePhotoUrl = ref.watch(profileControllerProvider.select((p) => p.photoUrl));

    ref.listen<PhotoUploadState>(photoUploadControllerProvider, (previous, next) {
      if (next.status == PhotoUploadStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.failureType != null
                  ? localizedStorageFailureMessage(loc, next.failureType!)
                  : loc.photoOperationFailedError,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.changePhotoScreenTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.divider, width: 2),
                      image: _pickedPhotoFile != null
                          ? DecorationImage(image: FileImage(_pickedPhotoFile!), fit: BoxFit.cover)
                          : (!_photoRemoved && profilePhotoUrl != null
                              ? DecorationImage(image: NetworkImage(profilePhotoUrl), fit: BoxFit.cover)
                              : null),
                    ),
                    child: (_pickedPhotoFile == null && (_photoRemoved || profilePhotoUrl == null))
                        ? const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 56)
                        : null,
                  ),
                  if (photoUploadState.isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.primary,
                              value: photoUploadState.progress > 0 ? photoUploadState.progress : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: GestureDetector(
                      onTap: photoUploadState.isLoading ? null : _pickPhoto,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: photoUploadState.isLoading ? AppColors.divider : AppColors.primary,
                          border: Border.all(color: AppColors.background, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.onAccent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (photoUploadState.isLoading)
                Text(
                  loc.uploadingProgress((photoUploadState.progress * 100).clamp(0, 100).toStringAsFixed(0)),
                  style: AppTextStyles.caption,
                )
              else if (_pickedPhotoFile != null || (!_photoRemoved && profilePhotoUrl != null))
                TextButton(
                  onPressed: _removePhoto,
                  child: Text(loc.removePhotoButton),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
