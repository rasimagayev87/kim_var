import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../pinbox/presentation/providers/pinbox_providers.dart';
import '../screens/live_feed_all_pinboxes_screen.dart';
import 'live_feed_pinbox_card.dart';
import 'live_feed_section_header.dart';

const double _kCardWidth = 170;

/// "PinBox elanları" — last 3 [nearbyPinBoxesProvider] results by
/// [PinBox.createdAt] descending (the provider itself has no recency
/// ordering — see its own doc comment — so this sorts client-side).
class LiveFeedPinboxSection extends ConsumerWidget {
  const LiveFeedPinboxSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final pinboxesAsync = ref.watch(nearbyPinBoxesProvider);

    return pinboxesAsync.when(
      data: (pinboxes) {
        // `nearbyPinBoxesProvider` is a one-shot `FutureProvider.autoDispose`
        // (pinbox_providers.dart) — its fetch already excludes an expired
        // `pickupWindowEnd` at the moment it runs, but nothing re-invalidates
        // it just because time passed, so a box that expired since the last
        // fetch would otherwise linger in whatever result is still cached.
        // Re-checking against `DateTime.now()` here (evaluated fresh on
        // every rebuild) is what actually keeps this section honest for as
        // long as the provider stays alive.
        final active = pinboxes
            .where((r) => r.pinbox.pickupWindowEnd.isAfter(DateTime.now()))
            .toList();
        if (active.isEmpty) return const SizedBox.shrink();
        final sorted = [...active]
          ..sort((a, b) => b.pinbox.createdAt.compareTo(a.pinbox.createdAt));
        final latest = sorted.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LiveFeedSectionHeader(
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFFFF6B6B),
                title: loc.liveFeedSectionPinboxListings,
                onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LiveFeedAllPinboxesScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              // `LiveFeedPinboxCard` is taller than its sibling cards
              // (`LiveFeedOfferCard`/`LiveFeedEventCard`, which fit 210):
              // a shorter 1.2 image aspect ratio (vs 1.35) plus a 4th text
              // row (price row, on top of title/description/meta) push
              // its natural content height past 220 — confirmed via a
              // real "BOTTOM OVERFLOWED" report at that height.
              height: 244,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: latest.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => LiveFeedPinboxCard(
                  pinbox: latest[index].pinbox,
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
