import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../app_config/presentation/utils/read_only_guard.dart';
import '../../../waitlist/domain/entities/waitlist_entry.dart';
import '../../../waitlist/presentation/providers/waitlist_providers.dart';
import '../../data/repositories/firebase_review_repository.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => FirebaseReviewRepository(),
);

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final venueReviewsProvider = StreamProvider.autoDispose
    .family<List<Review>, String>((ref, venueId) {
      return ref.watch(reviewRepositoryProvider).watchVenueReviews(venueId);
    });

final myReviewForVenueProvider = StreamProvider.autoDispose
    .family<Review?, String>((ref, venueId) {
      final uid = _currentUid();
      if (uid == null) return Stream.value(null);
      return ref
          .watch(reviewRepositoryProvider)
          .watchMyReview(venueId: venueId, userId: uid);
    });

/// Non-null only once the signed-in user has a `seated` waitlist entry
/// at this venue — the "Rəy yaz" button's eligibility gate, and the
/// entry it hands `ReviewController.submit` as proof of visit.
final verifiedVisitProvider = StreamProvider.autoDispose
    .family<WaitlistEntry?, String>((ref, venueId) {
      final uid = _currentUid();
      if (uid == null) return Stream.value(null);
      return ref
          .watch(waitlistRepositoryProvider)
          .watchMyLatestSeatedEntry(venueId: venueId, userId: uid);
    });

class ReviewController {
  ReviewController(this._ref);

  final Ref _ref;

  Future<bool> submit({
    required String venueId,
    required int rating,
    required String comment,
    required String waitlistEntryId,
  }) async {
    final uid = _currentUid();
    if (uid == null) return false;
    if (!ensureWritableOrWarn(_ref.read(appConfigProvider))) return false;
    try {
      await _ref
          .read(reviewRepositoryProvider)
          .submitReview(
            venueId: venueId,
            userId: uid,
            rating: rating,
            comment: comment,
            waitlistEntryId: waitlistEntryId,
          );
      return true;
    } catch (e, st) {
      logError('review_providers.ReviewController.submit', e, st);
      return false;
    }
  }

  Future<bool> submitOwnerReply({
    required String reviewId,
    required String text,
  }) async {
    if (!ensureWritableOrWarn(_ref.read(appConfigProvider))) return false;
    try {
      await _ref
          .read(reviewRepositoryProvider)
          .submitOwnerReply(reviewId: reviewId, text: text);
      return true;
    } catch (e, st) {
      logError('review_providers.ReviewController.submitOwnerReply', e, st);
      return false;
    }
  }

  Future<bool> report({
    required String reviewId,
    required String venueId,
    required String reason,
  }) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref
          .read(reviewRepositoryProvider)
          .reportReview(
            reviewId: reviewId,
            venueId: venueId,
            reporterId: uid,
            reason: reason,
          );
      return true;
    } catch (e, st) {
      logError('review_providers.ReviewController.report', e, st);
      return false;
    }
  }
}

final reviewControllerProvider = Provider<ReviewController>(
  (ref) => ReviewController(ref),
);
