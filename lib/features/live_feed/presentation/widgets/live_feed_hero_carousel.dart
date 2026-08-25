import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../events/domain/entities/venue_event.dart';
import '../../../events/presentation/screens/event_details_screen.dart';

/// "Bu axşam" hero carousel — today's events, full-width, visibly
/// larger than every other Canlı card per the reference mockup. No
/// "Canlı izləyin" button: there's no live video streaming in this
/// app's MVP, so the card only ever opens [EventDetailsScreen]. The
/// LIVE pill only ever shows for [VenueEventStatus.live] — that
/// transition is server-driven (see [VenueEvent]'s own doc comment),
/// never guessed client-side from [VenueEvent.startAt]/[endAt].
class LiveFeedHeroCarousel extends StatefulWidget {
  final List<VenueEvent> events;

  const LiveFeedHeroCarousel({super.key, required this.events});

  @override
  State<LiveFeedHeroCarousel> createState() => _LiveFeedHeroCarouselState();
}

class _LiveFeedHeroCarouselState extends State<LiveFeedHeroCarousel> {
  late final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.events.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final event = widget.events[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _HeroCard(event: event, loc: loc),
              );
            },
          ),
        ),
        if (widget.events.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.events.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : ChatLightColors.cardSurface,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VenueEvent event;
  final AppLocalizations loc;

  const _HeroCard({required this.event, required this.loc});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChatLightColors.ink,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: event.id))),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (event.coverImageUrl != null) AppImage(event.coverImageUrl!, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [ChatLightColors.ink.withValues(alpha: 0.92), ChatLightColors.ink.withValues(alpha: 0.15)],
                  stops: const [0.35, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (event.status == VenueEventStatus.live)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF7C6CF2), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        loc.eventStatusLive.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.venueName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined, size: 14, color: Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('d MMM, HH:mm', loc.localeName).format(event.startAt),
                            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
