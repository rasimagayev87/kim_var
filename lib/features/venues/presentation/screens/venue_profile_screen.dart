import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../settings/map_location/domain/entities/map_location_settings.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';
import '../../../events/domain/entities/venue_event.dart';
import '../../../events/presentation/providers/venue_event_providers.dart';
import '../../../events/presentation/screens/category_label.dart';
import '../../../events/presentation/screens/event_details_screen.dart';
import '../../../reviews/presentation/widgets/venue_reviews_section.dart';
import '../../../venue_follow/presentation/providers/venue_follow_providers.dart';
import '../../../waitlist/presentation/widgets/waitlist_status_section.dart';
import '../../domain/entities/venue.dart';
import '../../domain/venue_open_status.dart';
import '../providers/venue_providers.dart';
import '../widgets/seat_availability_card.dart';
import '../widgets/venue_star_rating.dart';
import 'create_venue_screen.dart';

/// Full profile page for a single venue — opened by tapping a card in
/// the Kəşf et → Məkanlar list. Watches [venueByIdProvider] (realtime)
/// rather than taking a snapshot, so an edit made elsewhere (e.g. from
/// "Mənim məkanlarım") is reflected here immediately if this screen is
/// still open.
///
/// Deliberately no Gallery/Offers/Followers sections — none of those
/// features exist yet, and this app never ships a visible placeholder
/// for something that isn't real. The [Venue.gallery] field already
/// exists schema-wise for when a real gallery upload flow is built.
/// Events (`_VenueEventsSection`) and Reviews (`VenueReviewsSection`)
/// DO exist, each rendering nothing of its own when there's nothing
/// to show.
class VenueProfileScreen extends ConsumerWidget {
  final String venueId;

  const VenueProfileScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final venueAsync = ref.watch(venueByIdProvider(venueId));
    final isLiked =
        ref.watch(isVenueLikedByMeProvider(venueId)).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          venueAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            ),
            error: (error, _) => _ErrorState(message: '$error'),
            data: (venue) => venue == null
                ? _ErrorState(message: loc.venueGenericErrorMessage)
                : _VenueProfileContent(
                    venue: venue,
                    isLiked: isLiked,
                    onToggleLiked: () => ref
                        .read(venueControllerProvider)
                        .toggleLike(venueId, isCurrentlyLiked: isLiked),
                  ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: _OverlayCircleButton(
              icon: Icons.arrow_back_ios_new,
              iconSize: 16,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: ChatLightColors.inkSoft),
        ),
      ),
    );
  }
}

class _VenueProfileContent extends StatelessWidget {
  final Venue venue;
  final bool isLiked;
  final VoidCallback onToggleLiked;

  const _VenueProfileContent({
    required this.venue,
    required this.isLiked,
    required this.onToggleLiked,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isOpen = isVenueOpenNow(venue.openingHours, DateTime.now());
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && venue.isOwnedBy(currentUid);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _HeroImage(
            venue: venue,
            isLiked: isLiked,
            onToggleLiked: onToggleLiked,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ChatLightColors.ink,
                        ),
                      ),
                    ),
                    if (venue.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ],
                    if (venue.isPremium) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 20,
                        color: AppColors.gold,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                VenueRatingBadge(
                  rating: venue.rating,
                  starSize: 16,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ChatLightColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _CategoryPill(category: venue.category),
                    const SizedBox(width: 8),
                    _StatusPill(isOpen: isOpen),
                  ],
                ),
                const SizedBox(height: 18),
                SeatAvailabilityCard(venue: venue),
                if (venue.availableSeats != null) const SizedBox(height: 12),
                if (!isOwner) ...[
                  WaitlistStatusSection(venue: venue),
                  const SizedBox(height: 12),
                ],
                if (isOwner) ...[
                  _LiveAudienceCard(venue: venue),
                  const SizedBox(height: 12),
                ],
                _CheckinSection(venue: venue, isOwner: isOwner),
                _VenueEventsSection(venueId: venue.id),
                VenueReviewsSection(venue: venue),
                const SizedBox(height: 28),
                Text(
                  loc.venueScheduleLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ChatLightColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                _WeeklySchedule(hours: venue.openingHours),
                const SizedBox(height: 28),
                Text(
                  loc.venueLocationLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ChatLightColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                _MiniMap(venue: venue),
                const SizedBox(height: 14),
                _DirectionsRow(venue: venue),
                if (venue.socialLinks != null &&
                    !venue.socialLinks!.isEmpty) ...[
                  const SizedBox(height: 8),
                  _SocialLinksRow(links: venue.socialLinks!),
                ],
                if (venue.address.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    loc.venueFullAddressLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: ChatLightColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue.address,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: ChatLightColors.ink,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Tədbirlər" — this venue's own upcoming/live events, separate from
/// the merged Kəşf et → Təkliflər list (which is radius-scoped, not
/// per-venue). Renders nothing when there are none, same "don't show
/// an empty section" convention as `SeatAvailabilityCard`.
class _VenueEventsSection extends ConsumerWidget {
  final String venueId;

  const _VenueEventsSection({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final events = (ref.watch(venueEventsByVenueProvider(venueId)).valueOrNull ?? const [])
        .where((e) => e.status == VenueEventStatus.upcoming || e.status == VenueEventStatus.live)
        .toList();
    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.eventDetailsSectionTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
          ),
          const SizedBox(height: 10),
          for (final event in events) ...[
            _VenueEventRow(event: event),
            if (event != events.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _VenueEventRow extends StatelessWidget {
  final VenueEvent event;

  const _VenueEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Material(
      color: ChatLightColors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: event.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: event.coverImageUrl != null
                      ? AppImage(event.coverImageUrl!, thumbnail: true, fit: BoxFit.cover)
                      : Container(color: Colors.white, child: const Icon(Icons.celebration_outlined, color: ChatLightColors.inkSoft)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${eventCategoryLabel(loc, event.category)} · ${event.status == VenueEventStatus.live ? loc.eventStatusLive : loc.eventStatusUpcoming}',
                      style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final Venue venue;
  final bool isLiked;
  final VoidCallback onToggleLiked;

  const _HeroImage({
    required this.venue,
    required this.isLiked,
    required this.onToggleLiked,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: venue.photoUrl != null
              ? AppImage(venue.photoUrl!, fit: BoxFit.cover)
              : Container(
                  color: ChatLightColors.cardSurface,
                  alignment: Alignment.center,
                  child: Icon(
                    venueCategoryIcon(venue.category),
                    size: 64,
                    color: ChatLightColors.inkFaint,
                  ),
                ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          child: Row(
            children: [
              if (venue.category == VenueCategory.independentArtist) ...[
                _VenueFollowButton(venueId: venue.id),
                const SizedBox(width: 8),
              ],
              AnimatedScale(
                scale: isLiked ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: _OverlayCircleButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  iconSize: 18,
                  iconColor: isLiked ? AppColors.primary : Colors.white,
                  onTap: onToggleLiked,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "İzlə" — venue-level follow, only ever shown for
/// [VenueCategory.independentArtist] (see `_HeroImage`'s own gate).
/// Tapping while not following opens a confirm dialog explaining what
/// following actually changes (fully radius-independent notifications
/// + Canlı visibility, no geographic gate at all — see
/// `VenueFollowRepository`'s doc comment); tapping while already
/// following unfollows immediately, no confirm needed (mirrors every
/// other unfollow-style action in this app).
class _VenueFollowButton extends ConsumerWidget {
  final String venueId;

  const _VenueFollowButton({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = ref.watch(isVenueFollowedByMeProvider(venueId)).valueOrNull ?? false;

    return _OverlayCircleButton(
      icon: isFollowing ? Icons.notifications_active : Icons.notifications_none_outlined,
      iconSize: 18,
      iconColor: isFollowing ? AppColors.primary : Colors.white,
      onTap: () => isFollowing ? _unfollow(context, ref) : _confirmAndFollow(context, ref),
    );
  }

  Future<void> _unfollow(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final ok = await ref.read(venueFollowControllerProvider).toggle(venueId: venueId, isCurrentlyFollowing: true);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.venueGenericErrorMessage)));
    }
  }

  Future<void> _confirmAndFollow(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(loc.venueFollowConfirmTitle, style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(loc.venueFollowConfirmMessage, style: const TextStyle(color: ChatLightColors.inkSoft, fontSize: 14.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.venueFollowConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(venueFollowControllerProvider).toggle(venueId: venueId, isCurrentlyFollowing: false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.venueGenericErrorMessage)));
    }
  }
}

/// Same translucent circular chrome for both the back button and the
/// favorite button.
class _OverlayCircleButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback? onTap;

  const _OverlayCircleButton({
    required this.icon,
    required this.iconSize,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final VenueCategory category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ChatLightColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            venueCategoryIcon(category),
            size: 13,
            color: ChatLightColors.inkSoft,
          ),
          const SizedBox(width: 5),
          Text(
            venueCategoryLabel(loc, category),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ChatLightColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isOpen;

  const _StatusPill({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = isOpen
        ? ChatLightColors.onlineGreen
        : ChatLightColors.inkFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isOpen ? loc.venueOpenNowLabel : loc.venueClosedNowLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Owner-only — a real-time count of how many PeakPin users are
/// currently active (`lastSeen` within 15 minutes) within [Venue.
/// audienceRadiusKm]/[Venue.audienceRadiusMode] of this venue, via
/// [venueAudienceCountProvider]. Never shown to a non-owner viewing the
/// same venue, and never exposes which users specifically — aggregate
/// count only, same privacy stance as [_CheckinSection] below it.
class _LiveAudienceCard extends ConsumerWidget {
  final Venue venue;

  const _LiveAudienceCard({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final count = ref.watch(
      venueAudienceCountProvider((
        mode: venue.audienceRadiusMode,
        lat: venue.lat,
        lng: venue.lng,
        radiusKm: venue.audienceRadiusKm,
        country: venue.country,
      )),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: ChatLightColors.onlineDot,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.venueLiveAudienceCount(count),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ChatLightColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live "Hazırda N istifadəçi buradadır" row + check-in/check-out
/// button. Split out of [_VenueProfileContent] (which is a plain
/// StatelessWidget fed by the parent's watches) so only this row
/// rebuilds when the count or check-in state changes, not the whole
/// profile.
class _CheckinSection extends ConsumerWidget {
  final Venue venue;

  /// The owner checking in at their own venue (or, in practice, staff
  /// who'd be tempted to do the same) would inflate this count with
  /// activity that was never a real visiting customer — so the action
  /// itself is owner-only-hidden here, while the count stays visible
  /// to everyone including the owner (it's still useful information,
  /// just not something the owner should be able to pad).
  final bool isOwner;

  const _CheckinSection({required this.venue, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final count =
        ref.watch(venueActiveCheckinCountProvider(venue.id)).valueOrNull ?? 0;
    final isCheckedIn =
        ref.watch(isCheckedInHereProvider(venue.id)).valueOrNull ?? false;

    Future<void> handleTap() async {
      final result = await ref
          .read(venueControllerProvider)
          .toggleCheckin(venue, isCurrentlyCheckedInHere: isCheckedIn);
      if (!context.mounted) return;
      final message = switch (result) {
        CheckinToggleResult.tooFar => loc.venueCheckinTooFar,
        CheckinToggleResult.locationUnavailable =>
          loc.venueCheckinLocationUnavailable,
        CheckinToggleResult.error ||
        CheckinToggleResult.notSignedIn => loc.venueGenericErrorMessage,
        CheckinToggleResult.success => null,
      };
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Icon(
            Icons.people_alt_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.venueCheckinActiveCount(count),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ChatLightColors.ink,
              ),
            ),
          ),
          if (!isOwner) ...[
            const SizedBox(width: 10),
            _CheckinButton(isCheckedIn: isCheckedIn, onTap: handleTap),
          ],
        ],
      ),
    );
  }
}

class _CheckinButton extends StatelessWidget {
  final bool isCheckedIn;
  final VoidCallback onTap;

  const _CheckinButton({required this.isCheckedIn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Material(
      color: isCheckedIn ? Colors.white : AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary),
          ),
          child: Text(
            isCheckedIn ? loc.venueCheckOutButton : loc.venueCheckInButton,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isCheckedIn ? AppColors.primary : AppColors.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklySchedule extends StatelessWidget {
  final OpeningHours hours;

  const _WeeklySchedule({required this.hours});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (hours.is24h) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              loc.venueHours24Label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ChatLightColors.ink,
              ),
            ),
          ],
        ),
      );
    }

    final today = DateTime.now().weekday;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var weekday = 1; weekday <= 7; weekday++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      _weekdayLabel(loc, weekday),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: weekday == today
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: weekday == today
                            ? AppColors.primary
                            : ChatLightColors.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      hours.schedule[weekday] == null
                          ? loc.venueClosedNowLabel
                          : '${hours.schedule[weekday]!.open} – ${hours.schedule[weekday]!.close}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: weekday == today
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: hours.schedule[weekday] == null
                            ? ChatLightColors.inkFaint
                            : ChatLightColors.inkSoft,
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

  String _weekdayLabel(AppLocalizations loc, int weekday) {
    return switch (weekday) {
      1 => loc.venueWeekdayMon,
      2 => loc.venueWeekdayTue,
      3 => loc.venueWeekdayWed,
      4 => loc.venueWeekdayThu,
      5 => loc.venueWeekdayFri,
      6 => loc.venueWeekdaySat,
      _ => loc.venueWeekdaySun,
    };
  }
}

class _MiniMap extends ConsumerWidget {
  final Venue venue;

  const _MiniMap({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapLocationSettings =
        ref.watch(mapLocationSettingsProvider).valueOrNull ??
        const MapLocationSettings();
    final center = LatLng(venue.lat, venue.lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        child: IgnorePointer(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 15.5),
            mapType: toGoogleMapType(mapLocationSettings.mapType),
            markers: {
              Marker(markerId: const MarkerId('venue'), position: center),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
        ),
      ),
    );
  }
}

class _DirectionsRow extends StatelessWidget {
  final Venue venue;

  const _DirectionsRow({required this.venue});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final lat = venue.lat;
    final lng = venue.lng;

    return Row(
      children: [
        Expanded(
          child: _DirectionsButton(
            icon: Icons.map_outlined,
            label: loc.venueDirectionsGoogleMaps,
            onTap: () => _open(
              'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DirectionsButton(
            icon: Icons.map_outlined,
            label: loc.venueDirectionsAppleMaps,
            onTap: () => _open('https://maps.apple.com/?daddr=$lat,$lng'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DirectionsButton(
            icon: Icons.navigation_outlined,
            label: loc.venueDirectionsWaze,
            onTap: () => _open('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
          ),
        ),
      ],
    );
  }
}

/// Only the WhatsApp/Instagram/TikTok buttons the owner actually filled
/// in are built — [VenueSocialLinks] fields are null unless present,
/// so this never renders a dead-end button for an empty field.
///
/// Brand recognition comes from a colored icon badge (a plain white
/// Material icon on the brand's own color/gradient — the same
/// icon-in-colored-badge language `_CategoryField`/`_CheckinButton`
/// already use elsewhere on this screen) rather than an exact brand
/// logotype: `font_awesome_flutter` was tried first but its bundled
/// `IconData` subclasses don't compile against this Flutter SDK
/// (`IconData` is a `final class` here), and hand-drawn SVG path data
/// for three brand marks risked shipping a subtly-wrong glyph with no
/// easy way to verify it. This needs zero new dependencies and can't
/// render incorrectly.
// Real brand marks (not a generic stand-in icon) — path data pulled
// verbatim from the Simple Icons project (simple-icons/simple-icons,
// MIT-licensed), each a single 0-0-24-24 viewBox path. Kept as raw SVG
// strings rendered via flutter_svg's SvgPicture.string rather than
// IconData: `font_awesome_flutter` was tried first for this, but its
// bundled IconData subclasses don't compile against this Flutter SDK
// (IconData is a `final class` here, so it can't be extended) — SVG
// sidesteps that entirely, and pulling real path data instead of
// hand-drawing it avoids shipping a subtly-wrong glyph.
const _kWhatsappSvgPath =
    'M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z';

const _kInstagramSvgPath =
    'M7.0301.084c-1.2768.0602-2.1487.264-2.911.5634-.7888.3075-1.4575.72-2.1228 1.3877-.6652.6677-1.075 1.3368-1.3802 2.127-.2954.7638-.4956 1.6365-.552 2.914-.0564 1.2775-.0689 1.6882-.0626 4.947.0062 3.2586.0206 3.6671.0825 4.9473.061 1.2765.264 2.1482.5635 2.9107.308.7889.72 1.4573 1.388 2.1228.6679.6655 1.3365 1.0743 2.1285 1.38.7632.295 1.6361.4961 2.9134.552 1.2773.056 1.6884.069 4.9462.0627 3.2578-.0062 3.668-.0207 4.9478-.0814 1.28-.0607 2.147-.2652 2.9098-.5633.7889-.3086 1.4578-.72 2.1228-1.3881.665-.6682 1.0745-1.3378 1.3795-2.1284.2957-.7632.4966-1.636.552-2.9124.056-1.2809.0692-1.6898.063-4.948-.0063-3.2583-.021-3.6668-.0817-4.9465-.0607-1.2797-.264-2.1487-.5633-2.9117-.3084-.7889-.72-1.4568-1.3876-2.1228C21.2982 1.33 20.628.9208 19.8378.6165 19.074.321 18.2017.1197 16.9244.0645 15.6471.0093 15.236-.005 11.977.0014 8.718.0076 8.31.0215 7.0301.0839m.1402 21.6932c-1.17-.0509-1.8053-.2453-2.2287-.408-.5606-.216-.96-.4771-1.3819-.895-.422-.4178-.6811-.8186-.9-1.378-.1644-.4234-.3624-1.058-.4171-2.228-.0595-1.2645-.072-1.6442-.079-4.848-.007-3.2037.0053-3.583.0607-4.848.05-1.169.2456-1.805.408-2.2282.216-.5613.4762-.96.895-1.3816.4188-.4217.8184-.6814 1.3783-.9003.423-.1651 1.0575-.3614 2.227-.4171 1.2655-.06 1.6447-.072 4.848-.079 3.2033-.007 3.5835.005 4.8495.0608 1.169.0508 1.8053.2445 2.228.408.5608.216.96.4754 1.3816.895.4217.4194.6816.8176.9005 1.3787.1653.4217.3617 1.056.4169 2.2263.0602 1.2655.0739 1.645.0796 4.848.0058 3.203-.0055 3.5834-.061 4.848-.051 1.17-.245 1.8055-.408 2.2294-.216.5604-.4763.96-.8954 1.3814-.419.4215-.8181.6811-1.3783.9-.4224.1649-1.0577.3617-2.2262.4174-1.2656.0595-1.6448.072-4.8493.079-3.2045.007-3.5825-.006-4.848-.0608M16.953 5.5864A1.44 1.44 0 1 0 18.39 4.144a1.44 1.44 0 0 0-1.437 1.4424M5.8385 12.012c.0067 3.4032 2.7706 6.1557 6.173 6.1493 3.4026-.0065 6.157-2.7701 6.1506-6.1733-.0065-3.4032-2.771-6.1565-6.174-6.1498-3.403.0067-6.156 2.771-6.1496 6.1738M8 12.0077a4 4 0 1 1 4.008 3.9921A3.9996 3.9996 0 0 1 8 12.0077';

const _kTiktokSvgPath =
    'M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z';

String _brandSvg(String pathData) =>
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="$pathData"/></svg>';

class _SocialLinksRow extends StatelessWidget {
  final VenueSocialLinks links;

  const _SocialLinksRow({required this.links});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final buttons = <Widget>[
      if (links.whatsapp != null)
        _SocialButton(
          svg: _brandSvg(_kWhatsappSvgPath),
          badgeColor: const Color(0xFF25D366),
          label: loc.venueSocialWhatsapp,
          onTap: () => _open('https://wa.me/${_digitsOnly(links.whatsapp!)}'),
        ),
      if (links.instagram != null)
        _SocialButton(
          svg: _brandSvg(_kInstagramSvgPath),
          badgeGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFEDA75),
              Color(0xFFD62976),
              Color(0xFF962FBF),
              Color(0xFF4F5BD5),
            ],
          ),
          label: loc.venueSocialInstagram,
          onTap: () =>
              _open('https://instagram.com/${_stripAt(links.instagram!)}'),
        ),
      if (links.tiktok != null)
        _SocialButton(
          svg: _brandSvg(_kTiktokSvgPath),
          badgeColor: Colors.black,
          label: loc.venueSocialTiktok,
          onTap: () => _open('https://tiktok.com/@${_stripAt(links.tiktok!)}'),
        ),
    ];

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  String _stripAt(String raw) =>
      raw.trim().startsWith('@') ? raw.trim().substring(1) : raw.trim();
}

/// Same footprint as [_DirectionsButton] (Google/Apple Maps/Waze) —
/// white card, 14px radius, icon-over-label column — so the two rows
/// read as one continuous set of "open externally" actions. The only
/// difference is the icon sits in a small brand-colored circular badge
/// instead of being a bare colored glyph, since these three marks (real
/// logos, not app-primary-colored outlines) need their own color to be
/// recognizable at all.
class _SocialButton extends StatelessWidget {
  final String svg;
  final Color? badgeColor;
  final Gradient? badgeGradient;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.svg,
    this.badgeColor,
    this.badgeGradient,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: badgeColor,
                  gradient: badgeGradient,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: SvgPicture.string(
                  svg,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ChatLightColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DirectionsButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ChatLightColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
