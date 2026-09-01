import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/screens/venue_profile_screen.dart';

/// "İndi boş yer var" card — deliberately the one section built around
/// the VENUE's own [Venue.photoUrl], not a posted listing's image
/// (there is no listing here; this card represents the venue itself,
/// same reasoning `SeatAvailabilityCard` already uses on
/// `VenueProfileScreen`). Circular photo instead of the rounded-square
/// thumbnail every other Canlı card uses, matching the reference
/// mockup's "this is a place, not a post" visual distinction.
class LiveFeedSeatCard extends StatelessWidget {
  final Venue venue;
  final double? width;

  const LiveFeedSeatCard({super.key, required this.venue, this.width});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final seats = venue.availableSeats ?? 0;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VenueProfileScreen(venueId: venue.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: venue.photoUrl != null
                        ? AppImage(
                            venue.photoUrl!,
                            thumbnail: true,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: ChatLightColors.cardSurface,
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: ChatLightColors.inkSoft,
                              size: 18,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: ChatLightColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.seatsAvailableLabel(seats),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: ChatLightColors.cardSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: ChatLightColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
