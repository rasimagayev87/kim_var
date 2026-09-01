import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/review.dart';
import '../providers/review_providers.dart';

import '../../../../core/widgets/pressable.dart';

/// Opens the star-rating + comment sheet for [venueId] — [waitlistEntryId]
/// is the caller's already-verified `seated` entry (`VenueReviewsSection`
/// only ever shows the "Rəy yaz" button once one exists), and
/// [existingReview] pre-fills the fields when the caller already has a
/// review here (same doc gets overwritten, not duplicated — see
/// `Review`'s own doc comment on the `{venueId}_{userId}` id scheme).
Future<void> showWriteReviewSheet(
  BuildContext context, {
  required String venueId,
  required String waitlistEntryId,
  Review? existingReview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _WriteReviewSheet(
      venueId: venueId,
      waitlistEntryId: waitlistEntryId,
      existingReview: existingReview,
    ),
  );
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final String venueId;
  final String waitlistEntryId;
  final Review? existingReview;

  const _WriteReviewSheet({
    required this.venueId,
    required this.waitlistEntryId,
    this.existingReview,
  });

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  late int _rating = widget.existingReview?.rating ?? 5;
  late final _commentController = TextEditingController(
    text: widget.existingReview?.comment ?? '',
  );
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final loc = AppLocalizations.of(context);
    setState(() => _submitting = true);
    final ok = await ref
        .read(reviewControllerProvider)
        .submit(
          venueId: widget.venueId,
          rating: _rating,
          comment: _commentController.text.trim(),
          waitlistEntryId: widget.waitlistEntryId,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _submitting = false);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? loc.reviewsSubmitSuccessMessage : loc.reviewsSubmitErrorMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ChatLightColors.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              loc.reviewsSheetTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ChatLightColors.ink,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              loc.reviewsSheetRatingLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ChatLightColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return Pressable(
                  onTap: () => setState(() => _rating = star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 34,
                      color: AppColors.gold,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _commentController,
              onChanged: (_) => setState(() {}),
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: loc.reviewsSheetCommentHint,
                filled: true,
                fillColor: ChatLightColors.bg1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onAccent,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.6,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitting || _commentController.text.trim().isEmpty
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.onAccent,
                        ),
                      )
                    : Text(
                        loc.reviewsSheetSubmitButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onAccent,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
