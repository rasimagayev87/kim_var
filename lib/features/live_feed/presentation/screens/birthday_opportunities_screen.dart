import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../providers/birthday_feed_providers.dart';
import '../widgets/live_feed_birthday_section.dart';

/// The full "Ad günü fürsətləri" list — where the 13:00 notification
/// lands (`targetType: 'birthday_feed'`).
///
/// Shows every venue in `users/{uid}/birthdayFeed/{dateKey}`, best
/// first, where the Canlı section shows the first six. The list is the
/// reason the push names only three venues: the rest are here.
class BirthdayOpportunitiesScreen extends ConsumerWidget {
  const BirthdayOpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final feedAsync = ref.watch(myBirthdayFeedProvider);

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        title: Text(loc.birthdayScreenTitle),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: feedAsync.when(
        data: (feed) {
          // Reachable by tapping yesterday's notification, or after the
          // TTL removed the document — the greeting is stale either way.
          if (feed == null || feed.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  loc.birthdayEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ChatLightColors.inkSoft),
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: feed.venueIds.length,
            itemBuilder: (context, index) => BirthdayVenueCard(venueId: feed.venueIds[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            loc.birthdayEmpty,
            style: const TextStyle(fontSize: 14, color: ChatLightColors.inkSoft),
          ),
        ),
      ),
    );
  }
}
