import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../offers/presentation/providers/offer_providers.dart';
import '../screens/live_feed_all_offers_screen.dart';
import 'live_feed_offer_card.dart';
import 'live_feed_section_header.dart';

const double _kCardWidth = 160;

/// "Yaxınlıqdakı təkliflər" — last 3 [nearbyOffersProvider] results by
/// [Offer.startDate] descending. Offers have no `createdAt` field (see
/// `Offer`'s doc comment on why — mirrors `Venue`'s own "single source
/// of truth, no drift-prone denormalized field" reasoning), so
/// `startDate` (when the offer actually went live) is the closest
/// available stand-in for "most recently posted."
class LiveFeedOffersSection extends ConsumerWidget {
  const LiveFeedOffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final offersAsync = ref.watch(nearbyOffersProvider);

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        final sorted = [...offers]
          ..sort((a, b) => b.offer.startDate.compareTo(a.offer.startDate));
        final latest = sorted.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LiveFeedSectionHeader(
                icon: Icons.bolt,
                iconColor: AppColors.primary,
                title: loc.liveFeedSectionOffersNearby,
                onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LiveFeedAllOffersScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: latest.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => LiveFeedOfferCard(
                  offer: latest[index].offer,
                  distanceMeters: latest[index].distanceMeters,
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
