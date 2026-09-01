import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/venue_event_providers.dart';

const _kEventAccent = Color(0xFF7C6CF2);

/// "🎤 Bu axşam: [Tədbir başlığı]" strip for a Discover → Məkanlar venue
/// card — only ever shows when [venueTodayEventProvider] resolves to a
/// non-null, `isToday` event (see that provider/`VenueEvent.isToday`'s
/// doc comments). Renders nothing while loading or when there's no
/// event today, so it never shifts a venue card's layout unexpectedly
/// once the fetch resolves — cards are already sized without it.
class VenueEventBanner extends ConsumerWidget {
  final String venueId;

  const VenueEventBanner({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(venueTodayEventProvider(venueId)).valueOrNull;
    if (event == null) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kEventAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        loc.eventTodayBannerLabel(event.title),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kEventAccent,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
