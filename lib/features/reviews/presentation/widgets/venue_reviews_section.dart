import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/widgets/venue_star_rating.dart';
import '../../domain/entities/review.dart';
import '../providers/review_providers.dart';
import 'write_review_sheet.dart';

/// "Rəylər" — only ever shown when there's something to see (existing
/// reviews) or something to do (the signed-in user is eligible to
/// write one), same "render nothing rather than an empty placeholder"
/// convention as `_VenueEventsSection`/`SeatAvailabilityCard` on this
/// same screen. Reviews are read-open to everyone regardless of
/// eligibility — only the "Rəy yaz" button itself is gated.
class VenueReviewsSection extends ConsumerWidget {
  final Venue venue;

  const VenueReviewsSection({super.key, required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final reviews =
        ref.watch(venueReviewsProvider(venue.id)).valueOrNull ??
        const <Review>[];
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && venue.isOwnedBy(currentUid);
    final verifiedEntry = isOwner
        ? null
        : ref.watch(verifiedVisitProvider(venue.id)).valueOrNull;
    final myReview = ref.watch(myReviewForVenueProvider(venue.id)).valueOrNull;

    final canWrite = verifiedEntry != null;
    if (reviews.isEmpty && !canWrite) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.reviewsSectionTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ChatLightColors.ink,
                ),
              ),
              if (canWrite)
                TextButton(
                  onPressed: () => showWriteReviewSheet(
                    context,
                    venueId: venue.id,
                    waitlistEntryId: verifiedEntry.id,
                    existingReview: myReview,
                  ),
                  child: Text(
                    loc.reviewsWriteButton,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RatingSummary(reviews: reviews, loc: loc),
            const SizedBox(height: 16),
            for (final review in reviews) ...[
              _ReviewCard(review: review, isVenueOwner: isOwner),
              if (review != reviews.last) const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final List<Review> reviews;
  final AppLocalizations loc;

  const _RatingSummary({required this.reviews, required this.loc});

  @override
  Widget build(BuildContext context) {
    final average =
        reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;
    final counts = List.generate(
      5,
      (i) => reviews.where((r) => r.rating == 5 - i).length,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatLightColors.bg1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: ChatLightColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              VenueStarRating(rating: average, size: 14),
              const SizedBox(height: 4),
              Text(
                loc.reviewsRatingCountLabel(reviews.length),
                style: const TextStyle(
                  fontSize: 11,
                  color: ChatLightColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i < 4 ? 4 : 0),
                    child: _DistributionBar(
                      star: 5 - i,
                      count: counts[i],
                      total: reviews.length,
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

class _DistributionBar extends StatelessWidget {
  final int star;
  final int count;
  final int total;

  const _DistributionBar({
    required this.star,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 12,
          child: Text(
            '$star',
            style: const TextStyle(
              fontSize: 10.5,
              color: ChatLightColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: ChatLightColors.cardSurface,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final Review review;
  final bool isVenueOwner;

  const _ReviewCard({required this.review, required this.isVenueOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = ref.watch(publicProfileProvider(review.userId)).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: ChatLightColors.cardSurface,
              backgroundImage: profile?.photoUrl != null
                  ? NetworkImage(profile!.photoUrl!)
                  : null,
              child: profile?.photoUrl == null
                  ? const Icon(
                      Icons.person_outline,
                      color: ChatLightColors.inkSoft,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile?.name.trim().isNotEmpty == true
                              ? profile!.name
                              : (profile?.username ?? ''),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: ChatLightColors.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatRelativeTime(review.createdAt, loc),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: ChatLightColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      VenueStarRating(
                        rating: review.rating.toDouble(),
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F8EC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 11,
                              color: Color(0xFF1F9254),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              loc.reviewsVerifiedBadge,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F9254),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _ReportReviewButton(review: review),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          review.comment,
          style: const TextStyle(
            fontSize: 14,
            color: ChatLightColors.ink,
            height: 1.4,
          ),
        ),
        if (review.ownerReply != null) ...[
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.only(left: 42),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ChatLightColors.bg1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.reviewsOwnerReplyLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  review.ownerReply!.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ChatLightColors.ink,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ] else if (isVenueOwner) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showOwnerReplySheet(context, ref, review),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                loc.reviewsOwnerReplySubmitButton,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Şikayət et" — a review's own author/owner can't delete it directly
/// (see `Review`'s doc comment); this is the only lever, writing
/// `reviewReports/{id}` for the admin panel's moderation queue, same
/// shape as `EventReportButton`.
/// The venue owner's one-time public reply — a plain text field in a
/// bottom sheet, gone as soon as it's submitted since there's nothing
/// left to edit (`firestore.rules` rejects a second one outright, see
/// `Review.ownerReply`'s doc comment).
Future<void> _showOwnerReplySheet(
  BuildContext context,
  WidgetRef ref,
  Review review,
) async {
  final loc = AppLocalizations.of(context);
  final controller = TextEditingController();
  final text = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.reviewsOwnerReplyLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ChatLightColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: loc.reviewsOwnerReplyHint,
                filled: true,
                fillColor: ChatLightColors.bg1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  final trimmed = controller.text.trim();
                  if (trimmed.isEmpty) return;
                  Navigator.pop(sheetContext, trimmed);
                },
                child: Text(
                  loc.reviewsOwnerReplySubmitButton,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (text == null || !context.mounted) return;

  final ok = await ref
      .read(reviewControllerProvider)
      .submitOwnerReply(reviewId: review.id, text: text);
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.reviewsOwnerReplyErrorMessage)));
  }
}

class _ReportReviewButton extends ConsumerWidget {
  final Review review;

  const _ReportReviewButton({required this.review});

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.eventReportSheetTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ChatLightColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(loc.eventReportReasonSpam),
              onTap: () => Navigator.pop(sheetContext, 'spam'),
            ),
            ListTile(
              title: Text(loc.eventReportReasonInappropriate),
              onTap: () => Navigator.pop(sheetContext, 'inappropriate'),
            ),
            ListTile(
              title: Text(loc.eventReportReasonOther),
              onTap: () => Navigator.pop(sheetContext, 'other'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    final ok = await ref
        .read(reviewControllerProvider)
        .report(reviewId: review.id, venueId: review.venueId, reason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? loc.eventReportSubmittedMessage : loc.eventReportErrorMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => _report(context, ref),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: const Icon(
        Icons.flag_outlined,
        size: 16,
        color: ChatLightColors.inkFaint,
      ),
    );
  }
}
