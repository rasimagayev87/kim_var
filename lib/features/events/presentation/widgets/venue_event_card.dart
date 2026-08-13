import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/distance_formatter.dart';
import '../../../../core/utils/distance_unit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/venue_event.dart';
import '../../domain/repositories/venue_event_repository.dart';
import '../screens/category_label.dart';
import '../screens/event_details_screen.dart';

/// Purple "Tədbir" badge — deliberately distinct from `_OfferTypeBadge`'s
/// green/orange/red discount colors, per the spec's "Təklif kartlarından
/// fərqli badge" requirement, so a merged Hamısı list reads as two kinds
/// of thing at a glance, not one.
const _kEventAccent = Color(0xFF7C6CF2);

/// Same card shape/sizing as `_OfferCard` in `offer_list_view.dart` —
/// deliberately mirrored, not shared, since the two only look alike by
/// coincidence of both being "Kəşf et list item" cards; sharing a base
/// class over two fields (badge color/label) would be more machinery
/// than the duplication it removes.
class VenueEventCard extends StatelessWidget {
  final VenueEventWithDistance item;
  final DistanceUnit distanceUnit;

  const VenueEventCard({super.key, required this.item, required this.distanceUnit});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final event = item.event;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: event.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: event.coverImageUrl != null
                      ? Image.network(event.coverImageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: ChatLightColors.cardSurface,
                          alignment: Alignment.center,
                          child: const Icon(Icons.celebration_outlined, color: ChatLightColors.inkSoft, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.venueName,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kEventAccent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      eventCategoryLabel(loc, event.category),
                      style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12.5, color: ChatLightColors.inkFaint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            formatDistance(loc, item.distanceMeters, distanceUnit),
                            style: const TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.schedule_outlined, size: 12.5, color: ChatLightColors.inkFaint),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('d MMM, HH:mm').format(event.startAt),
                          style: const TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _kEventAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎤', style: TextStyle(fontSize: 14)),
                    Text(
                      event.status == VenueEventStatus.live ? loc.eventStatusLive : loc.eventBadgeLabel,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _kEventAccent),
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
