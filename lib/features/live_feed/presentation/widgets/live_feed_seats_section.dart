import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../venues/presentation/providers/venue_providers.dart';
import '../../../waitlist/presentation/providers/waitlist_providers.dart';
import '../screens/live_feed_all_seats_screen.dart';
import 'live_feed_seat_card.dart';
import 'live_feed_section_header.dart';

const double _kCardWidth = 190;

/// "İndi boş yer var" — [nearbyVenuesProvider] filtered to venues
/// currently reporting free seats, gated by the same
/// [waitlistCategoryConfigProvider] eligibility set `SeatAvailabilityCard`
/// already applies. Last 3 by [Venue.seatsUpdatedAt] descending — the
/// closest "recency" signal available here, since a venue itself has
/// no "posted" timestamp the way a listing does.
class LiveFeedSeatsSection extends ConsumerWidget {
  const LiveFeedSeatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final venuesAsync = ref.watch(nearbyVenuesProvider);
    final eligibleCategories =
        ref.watch(waitlistCategoryConfigProvider).valueOrNull ?? const {};

    return venuesAsync.when(
      data: (venues) {
        final withSeats =
            venues
                .where(
                  (v) =>
                      (v.venue.availableSeats ?? 0) > 0 &&
                      eligibleCategories.contains(v.venue.category),
                )
                .toList()
              ..sort(
                (a, b) => (b.venue.seatsUpdatedAt ?? DateTime(0)).compareTo(
                  a.venue.seatsUpdatedAt ?? DateTime(0),
                ),
              );
        if (withSeats.isEmpty) return const SizedBox.shrink();
        final latest = withSeats.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LiveFeedSectionHeader(
                icon: Icons.event_seat_outlined,
                iconColor: AppColors.cyanDark,
                title: loc.liveFeedSectionSeatsNow,
                onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LiveFeedAllSeatsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: latest.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => LiveFeedSeatCard(
                  venue: latest[index].venue,
                  width: _kCardWidth,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
