import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../events/presentation/providers/venue_event_providers.dart';
import 'live_feed_event_filters.dart';
import 'live_feed_hero_carousel.dart';

/// "Bu axşam" — see [isTonightHeroEvent] for exactly which events
/// qualify (currently live, or starting this evening today). Renders
/// nothing at all when there's no such event, rather than an empty
/// hero slot.
class LiveFeedHeroSection extends ConsumerWidget {
  const LiveFeedHeroSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(nearbyEventsProvider);

    return eventsAsync.when(
      data: (items) {
        final tonight = items
            .map((item) => item.event)
            .where(isTonightHeroEvent)
            .toList();
        if (tonight.isEmpty) return const SizedBox.shrink();
        return LiveFeedHeroCarousel(events: tonight);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
