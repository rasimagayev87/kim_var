import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/providers/venue_event_providers.dart';
import '../screens/live_feed_all_events_screen.dart';
import 'live_feed_event_card.dart';
import 'live_feed_event_filters.dart';
import 'live_feed_section_header.dart';

const double _kCardWidth = 170;

/// "Tədbirlər" — last 3 [nearbyEventsProvider] results (by
/// [VenueEvent.createdAt] descending) that DIDN'T qualify for
/// [LiveFeedHeroSection] (see [isTonightHeroEvent]) — every event
/// lands in exactly one of the two sections, never both.
class LiveFeedEventsSection extends ConsumerWidget {
  const LiveFeedEventsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final eventsAsync = ref.watch(nearbyEventsProvider);

    return eventsAsync.when(
      data: (events) {
        final rest = events.where((item) => !isTonightHeroEvent(item.event)).toList();
        if (rest.isEmpty) return const SizedBox.shrink();
        final sorted = [...rest]..sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));
        final latest = sorted.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LiveFeedSectionHeader(
                icon: Icons.event_outlined,
                iconColor: const Color(0xFF7C6CF2),
                title: loc.liveFeedSectionEvents,
                onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveFeedAllEventsScreen())),
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
                itemBuilder: (context, index) =>
                    LiveFeedEventCard(event: latest[index].event, distanceMeters: latest[index].distanceMeters, width: _kCardWidth),
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
