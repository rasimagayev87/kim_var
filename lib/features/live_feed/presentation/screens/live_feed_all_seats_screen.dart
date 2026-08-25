import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../venues/presentation/providers/venue_providers.dart';
import '../../../waitlist/presentation/providers/waitlist_providers.dart';
import '../widgets/live_feed_seat_card.dart';

/// "Hamısına bax" destination for Canlı's "İndi boş yer var" — same
/// [nearbyVenuesProvider] filtered to venues currently reporting free
/// seats, same eligibility gate `SeatAvailabilityCard` already applies
/// on `VenueProfileScreen` ([waitlistCategoryConfigProvider]).
class LiveFeedAllSeatsScreen extends ConsumerWidget {
  const LiveFeedAllSeatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final venuesAsync = ref.watch(nearbyVenuesProvider);
    final eligibleCategories = ref.watch(waitlistCategoryConfigProvider).valueOrNull ?? const {};

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(loc.liveFeedSectionSeatsNow, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: venuesAsync.when(
        data: (venues) {
          final withSeats = venues
              .where((v) => (v.venue.availableSeats ?? 0) > 0 && eligibleCategories.contains(v.venue.category))
              .toList()
            ..sort((a, b) => (b.venue.seatsUpdatedAt ?? DateTime(0)).compareTo(a.venue.seatsUpdatedAt ?? DateTime(0)));
          return withSeats.isEmpty
              ? Center(child: Text(loc.venuesEmptyTitle, style: const TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: withSeats.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => LiveFeedSeatCard(venue: withSeats[index].venue),
                );
        },
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
        error: (_, _) => Center(child: Text(loc.venuesEmptyTitle, style: const TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }
}
