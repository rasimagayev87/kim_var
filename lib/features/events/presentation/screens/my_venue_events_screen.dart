import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/entities/venue_event.dart';
import '../providers/venue_event_providers.dart';
import 'create_event_screen.dart';

/// Owner-only "Tədbirlər" screen — reached from `MyVenuesScreen`'s
/// 3-dot menu. Upcoming/Live/Ended tabs over the same live
/// [venueEventsByVenueProvider] stream (client-side filtered by tab,
/// not three separate queries — the whole list for one venue is small
/// enough this doesn't need pagination).
class MyVenueEventsScreen extends ConsumerStatefulWidget {
  final Venue venue;

  const MyVenueEventsScreen({super.key, required this.venue});

  @override
  ConsumerState<MyVenueEventsScreen> createState() => _MyVenueEventsScreenState();
}

class _MyVenueEventsScreenState extends ConsumerState<MyVenueEventsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final eventsAsync = ref.watch(venueEventsByVenueProvider(widget.venue.id));

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        title: Text(
          loc.eventMyEventsTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateEventScreen(venue: widget.venue))),
            icon: const Icon(Icons.add, color: AppColors.primary),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: ChatLightColors.inkFaint,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: loc.eventTabUpcoming),
            Tab(text: loc.eventTabLive),
            Tab(text: loc.eventTabEnded),
          ],
        ),
      ),
      body: SafeArea(
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
          error: (error, _) => Center(child: Text('$error', style: const TextStyle(color: ChatLightColors.inkSoft))),
          data: (events) => TabBarView(
            controller: _tabController,
            children: [
              _EventList(events: events.where((e) => e.status == VenueEventStatus.upcoming).toList()),
              _EventList(events: events.where((e) => e.status == VenueEventStatus.live).toList()),
              _EventList(events: events.where((e) => e.status == VenueEventStatus.ended || e.status == VenueEventStatus.cancelled).toList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<VenueEvent> events;

  const _EventList({required this.events});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (events.isEmpty) {
      return Center(child: Text(loc.eventEmptyListMessage, style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _EventCard(event: events[index]),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final VenueEvent event;

  const _EventCard({required this.event});

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        content: Text(loc.eventCancelConfirmMessage, style: const TextStyle(color: ChatLightColors.ink, fontSize: 14.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(venueEventControllerProvider).cancelEvent(event.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final canCancel = event.status == VenueEventStatus.upcoming || event.status == VenueEventStatus.live;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: event.coverImageUrl != null
                  ? Image.network(event.coverImageUrl!, fit: BoxFit.cover)
                  : Container(color: ChatLightColors.cardSurface, child: const Icon(Icons.celebration_outlined, color: ChatLightColors.inkSoft)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
                const SizedBox(height: 4),
                Text(
                  '${event.startAt.day.toString().padLeft(2, '0')}.${event.startAt.month.toString().padLeft(2, '0')} · ${event.startAt.hour.toString().padLeft(2, '0')}:${event.startAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                ),
                if (canCancel) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _confirmCancel(context, ref),
                    child: Text(loc.eventCancelButton, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.error)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
