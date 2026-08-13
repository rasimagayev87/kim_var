import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../../domain/entities/venue_event.dart';
import '../providers/venue_event_providers.dart';
import '../widgets/event_report_button.dart';
import 'category_label.dart';

/// Full details page for a single event — opened by tapping a card in
/// Kəşf et → Təkliflər ("Tədbir" filter) or a `venueEvent` push
/// notification. Watches [venueEventByIdProvider] (realtime), same
/// reasoning as `OfferDetailsScreen`/`VenueProfileScreen`.
class EventDetailsScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final eventAsync = ref.watch(venueEventByIdProvider(eventId));

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      body: Stack(
        children: [
          const ChatLightBackground(),
          eventAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
            error: (error, _) => Center(child: Text('$error', style: const TextStyle(color: ChatLightColors.inkSoft))),
            data: (event) => event == null
                ? Center(child: Text(loc.venueGenericErrorMessage, style: const TextStyle(color: ChatLightColors.inkSoft)))
                : _EventDetailsContent(event: event),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: Material(
              color: Colors.black38,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailsContent extends StatelessWidget {
  final VenueEvent event;

  const _EventDetailsContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final dateFormat = DateFormat('d MMM, HH:mm');

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: event.coverImageUrl != null
                ? Image.network(event.coverImageUrl!, fit: BoxFit.cover)
                : Container(color: ChatLightColors.cardSurface, child: const Icon(Icons.celebration_outlined, size: 56, color: ChatLightColors.inkFaint)),
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
                        event.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF7C6CF2).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        loc.eventBadgeLabel,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7C6CF2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueProfileScreen(venueId: event.venueId))),
                  child: Text(
                    event.venueName,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 16, color: ChatLightColors.inkFaint),
                    const SizedBox(width: 6),
                    Text(
                      '${dateFormat.format(event.startAt)} – ${dateFormat.format(event.endAt)}',
                      style: const TextStyle(fontSize: 13, color: ChatLightColors.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ChatLightColors.cardSurface, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        eventCategoryLabel(loc, event.category),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  event.description,
                  style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink, height: 1.5),
                ),
                const SizedBox(height: 20),
                Align(alignment: Alignment.centerLeft, child: EventReportButton(eventId: event.id)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
