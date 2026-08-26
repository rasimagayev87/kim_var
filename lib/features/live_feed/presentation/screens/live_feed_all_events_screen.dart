import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/providers/venue_event_providers.dart';
import '../widgets/live_feed_event_card.dart';

/// "Hamısına bax" destination for Canlı's "Tədbirlər" — same
/// [nearbyEventsProvider] the carousel's last-3 is sliced from.
class LiveFeedAllEventsScreen extends ConsumerWidget {
  const LiveFeedAllEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final eventsAsync = ref.watch(nearbyEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(loc.liveFeedSectionEvents, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: eventsAsync.when(
        data: (events) => events.isEmpty
            ? Center(child: Text(loc.listingEmptyEventsSubtitle, style: const TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => LiveFeedEventCard(event: events[index].event, distanceMeters: events[index].distanceMeters),
              ),
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
        error: (_, _) => Center(child: Text(loc.listingEmptyEventsSubtitle, style: const TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }
}
