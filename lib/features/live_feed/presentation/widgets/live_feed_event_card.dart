import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/distance_formatter.dart';
import '../../../../core/utils/distance_unit.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../events/domain/entities/venue_event.dart';
import '../../../events/presentation/screens/event_details_screen.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';

const _kEventAccent = Color(0xFF7C6CF2);

/// Image-top event card for Canlı's "Tədbirlər" carousel and its
/// "Hamısına bax" full list — a NEW layout from the existing
/// `VenueEventCard` (that one is a left-icon row for a merged Kəşf et
/// list; this one leads with a big [VenueEvent.coverImageUrl] and a
/// day/month date badge, matching the reference mockup). No bookmark
/// icon: unlike offers, there's no favorite-event feature anywhere in
/// this app to back one — adding it would mean new backend, which this
/// visual-only pass explicitly doesn't do.
class LiveFeedEventCard extends ConsumerWidget {
  final VenueEvent event;
  final double distanceMeters;
  final double? width;

  const LiveFeedEventCard({super.key, required this.event, required this.distanceMeters, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final distanceUnit = ref.watch(mapLocationSettingsProvider).valueOrNull?.distanceUnit ?? DistanceUnit.km;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: event.id))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1.35,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      event.coverImageUrl != null
                          ? AppImage(event.coverImageUrl!, fit: BoxFit.cover)
                          : Container(color: ChatLightColors.cardSurface, child: const Icon(Icons.celebration_outlined, color: ChatLightColors.inkSoft)),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 40,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('d').format(event.startAt),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ChatLightColors.ink, height: 1.1),
                              ),
                              Text(
                                DateFormat('MMM', loc.localeName).format(event.startAt).toUpperCase(),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kEventAccent, height: 1.1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (event.status == VenueEventStatus.live)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _kEventAccent, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              loc.eventStatusLive.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.venueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 12, color: ChatLightColors.inkFaint),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('HH:mm').format(event.startAt),
                          style: const TextStyle(fontSize: 10.5, color: ChatLightColors.inkFaint),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.location_on_outlined, size: 12, color: ChatLightColors.inkFaint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            formatDistance(loc, distanceMeters, distanceUnit),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, color: ChatLightColors.inkFaint),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
