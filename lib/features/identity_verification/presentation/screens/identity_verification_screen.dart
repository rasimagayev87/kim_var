import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/storage_failure_messages.dart';
import '../../domain/entities/identity_verification_request.dart';
import '../providers/identity_verification_providers.dart';

/// Settings → "Kimlik doğrulama" — the ID+selfie submission flow that
/// (once admin-approved) sets `users/{uid}.identityVerified`, the same
/// field the profile's blue-check badge already reads (see
/// `profile_tab.dart`). Entirely separate from the phone-OTP
/// `isVerified` step; see `identityVerifications` collection's doc
/// comment in firestore.rules for the full split.
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends ConsumerState<IdentityVerificationScreen> {
  File? _idFront;
  File? _idBack;
  File? _selfie;

  /// Only meaningful while the latest request is `rejected` — flips
  /// the body back to the picker wizard instead of the rejection view.
  /// Resets itself implicitly: once a new submission lands, the stream
  /// provider's latest request becomes `pending`, which isn't the
  /// `rejected` branch this flag only affects.
  bool _resubmitting = false;

  Future<ImageSource?> _chooseSource(AppLocalizations loc) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary),
              title: Text(loc.identityVerificationSourceCameraOption),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
              title: Text(loc.identityVerificationSourceGalleryOption),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIdImage({required bool isFront}) async {
    final loc = AppLocalizations.of(context);
    final source = await _chooseSource(loc);
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      if (isFront) {
        _idFront = File(picked.path);
      } else {
        _idBack = File(picked.path);
      }
    });
  }

  /// Front camera only, live capture only — no gallery/back-camera
  /// choice here, unlike [_pickIdImage]. Matches the spec's explicit
  /// "canlı çəkiliş məcburi olsun" requirement: a gallery pick could be
  /// an old photo or someone else's, defeating the point of a selfie
  /// liveness/identity check.
  Future<void> _pickSelfie() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _selfie = File(picked.path));
  }

  Future<void> _submit() async {
    final idFront = _idFront;
    final idBack = _idBack;
    final selfie = _selfie;
    if (idFront == null || idBack == null || selfie == null) return;

    final controller = ref.read(identityVerificationSubmitControllerProvider.notifier);
    final ok = await controller.submit(idFront: idFront, idBack: idBack, selfieWithId: selfie);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _idFront = null;
        _idBack = null;
        _selfie = null;
        _resubmitting = false;
      });
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.identityVerificationSubmitSuccessMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final identityVerified = ref.watch(profileControllerProvider.select((p) => p.identityVerified));
    final latestRequestAsync = ref.watch(latestIdentityVerificationRequestProvider);
    final submitState = ref.watch(identityVerificationSubmitControllerProvider);

    ref.listen(identityVerificationSubmitControllerProvider, (previous, next) {
      if (next.status == IdentityVerificationSubmitStatus.error) {
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
        title: Text(loc.settingsIdentityVerificationRowTitle),
      ),
      body: SafeArea(
        child: identityVerified
            ? _AlreadyVerifiedView(loc: loc)
            : latestRequestAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
                error: (_, _) => Center(child: Text(loc.photoOperationFailedError)),
                data: (request) {
                  if (request != null && request.status == IdentityVerificationStatus.pending) {
                    return _PendingView(loc: loc);
                  }
                  if (request != null && request.status == IdentityVerificationStatus.rejected && !_resubmitting) {
                    return _RejectedView(
                      loc: loc,
                      reason: request.rejectionReason,
                      onResubmit: () => setState(() => _resubmitting = true),
                    );
                  }
                  return _UploadWizard(
                    loc: loc,
                    idFront: _idFront,
                    idBack: _idBack,
                    selfie: _selfie,
                    submitState: submitState,
                    onPickIdFront: () => _pickIdImage(isFront: true),
                    onPickIdBack: () => _pickIdImage(isFront: false),
                    onPickSelfie: _pickSelfie,
                    onSubmit: _submit,
                  );
                },
              ),
      ),
    );
  }
}

class _AlreadyVerifiedView extends StatelessWidget {
  final AppLocalizations loc;
  const _AlreadyVerifiedView({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              loc.identityVerificationAlreadyVerifiedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
            ),
            const SizedBox(height: 6),
            Text(
              loc.identityVerificationAlreadyVerifiedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  final AppLocalizations loc;
  const _PendingView({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded, size: 32, color: AppColors.gold),
            ),
            const SizedBox(height: 16),
            Text(
              loc.identityVerificationPendingTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
            ),
            const SizedBox(height: 6),
            Text(
              loc.identityVerificationPendingBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedView extends StatelessWidget {
  final AppLocalizations loc;
  final String? reason;
  final VoidCallback onResubmit;
  const _RejectedView({required this.loc, required this.reason, required this.onResubmit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 32, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              loc.identityVerificationRejectedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
            ),
            if (reason != null && reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${loc.moderationReviewNotePrefix}: ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.white),
                      ),
                      TextSpan(
                        text: reason,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onResubmit,
                child: Text(loc.identityVerificationResubmitButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadWizard extends StatelessWidget {
  final AppLocalizations loc;
  final File? idFront;
  final File? idBack;
  final File? selfie;
  final IdentityVerificationSubmitState submitState;
  final VoidCallback onPickIdFront;
  final VoidCallback onPickIdBack;
  final VoidCallback onPickSelfie;
  final VoidCallback onSubmit;

  const _UploadWizard({
    required this.loc,
    required this.idFront,
    required this.idBack,
    required this.selfie,
    required this.submitState,
    required this.onPickIdFront,
    required this.onPickIdBack,
    required this.onPickSelfie,
    required this.onSubmit,
  });

  bool get _allPicked => idFront != null && idBack != null && selfie != null;

  @override
  Widget build(BuildContext context) {
    final isLoading = submitState.isLoading;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            loc.identityVerificationInfoBanner,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        const SizedBox(height: 20),
        _ImageStepCard(
          stepNumber: 1,
          title: loc.identityVerificationStep1Title,
          file: idFront,
          buttonLabel: idFront == null ? loc.identityVerificationAddPhotoButton : loc.identityVerificationChangePhotoButton,
          onTap: isLoading ? null : onPickIdFront,
        ),
        const SizedBox(height: 14),
        _ImageStepCard(
          stepNumber: 2,
          title: loc.identityVerificationStep2Title,
          file: idBack,
          buttonLabel: idBack == null ? loc.identityVerificationAddPhotoButton : loc.identityVerificationChangePhotoButton,
          onTap: isLoading ? null : onPickIdBack,
        ),
        const SizedBox(height: 14),
        _ImageStepCard(
          stepNumber: 3,
          title: loc.identityVerificationStep3Title,
          file: selfie,
          buttonLabel: selfie == null ? loc.identityVerificationTakeSelfieButton : loc.identityVerificationChangePhotoButton,
          onTap: isLoading ? null : onPickSelfie,
        ),
        const SizedBox(height: 24),
        if (isLoading)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 4),
                CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                  value: submitState.progress > 0 ? submitState.progress : null,
                ),
                const SizedBox(height: 10),
                Text(
                  loc.uploadingProgress((submitState.progress * 100).clamp(0, 100).toStringAsFixed(0)),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _allPicked ? onSubmit : null,
              child: Text(loc.identityVerificationSubmitButton),
            ),
          ),
      ],
    );
  }
}

class _ImageStepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final File? file;
  final String buttonLabel;
  final VoidCallback? onTap;

  const _ImageStepCard({
    required this.stepNumber,
    required this.title,
    required this.file,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              image: file != null ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover) : null,
            ),
            child: file == null
                ? Center(
                    child: Text(
                      '$stepNumber',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.white),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(buttonLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
