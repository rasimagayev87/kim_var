import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../settings/map_location/domain/entities/map_location_settings.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';
import '../../domain/entities/venue.dart';
import '../../domain/venue_open_status.dart';
import '../providers/venue_providers.dart';
import 'create_venue_screen.dart';

/// Full profile page for a single venue — opened by tapping a card in
/// the Kəşf et → Məkanlar list. Watches [venueByIdProvider] (realtime)
/// rather than taking a snapshot, so an edit made elsewhere (e.g. from
/// "Mənim məkanlarım") is reflected here immediately if this screen is
/// still open.
///
/// Deliberately no Gallery/Offers/Events/Reviews/Followers/Check-ins
/// sections — none of those features exist yet, and this app never
/// ships a visible placeholder for something that isn't real. The
/// [Venue.gallery] field already exists schema-wise for when a real
/// gallery upload flow is built.
class VenueProfileScreen extends ConsumerWidget {
  final String venueId;

  const VenueProfileScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final venueAsync = ref.watch(venueByIdProvider(venueId));
    final isFavorite = ref.watch(favoriteVenueIdsProvider.select((async) => async.valueOrNull?.contains(venueId) ?? false));

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      body: Stack(
        children: [
          const ChatLightBackground(),
          venueAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
            error: (error, _) => _ErrorState(message: '$error'),
            data: (venue) => venue == null
                ? _ErrorState(message: loc.venueGenericErrorMessage)
                : _VenueProfileContent(
                    venue: venue,
                    isFavorite: isFavorite,
                    onToggleFavorite: () =>
                        ref.read(venueControllerProvider).toggleFavorite(venueId, isCurrentlyFavorite: isFavorite),
                  ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: _OverlayCircleButton(
              icon: Icons.arrow_back_ios_new,
              iconSize: 16,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: ChatLightColors.inkSoft)),
      ),
    );
  }
}

class _VenueProfileContent extends StatelessWidget {
  final Venue venue;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _VenueProfileContent({required this.venue, required this.isFavorite, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isOpen = isVenueOpenNow(venue.openingHours, DateTime.now());

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _HeroImage(venue: venue, isFavorite: isFavorite, onToggleFavorite: onToggleFavorite),
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
                        venue.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
                      ),
                    ),
                    if (venue.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 20, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _CategoryPill(category: venue.category),
                    const SizedBox(width: 8),
                    _StatusPill(isOpen: isOpen),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  loc.venueScheduleLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                ),
                const SizedBox(height: 10),
                _WeeklySchedule(hours: venue.openingHours),
                const SizedBox(height: 28),
                Text(
                  loc.venueLocationLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                ),
                const SizedBox(height: 10),
                _MiniMap(venue: venue),
                const SizedBox(height: 14),
                _DirectionsRow(venue: venue),
                if (venue.address.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    loc.venueFullAddressLabel,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue.address,
                    style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  final Venue venue;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _HeroImage({required this.venue, required this.isFavorite, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: venue.photoUrl != null
              ? Image.network(venue.photoUrl!, fit: BoxFit.cover)
              : Container(
                  color: ChatLightColors.cardSurface,
                  alignment: Alignment.center,
                  child: Icon(venueCategoryIcon(venue.category), size: 64, color: ChatLightColors.inkFaint),
                ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          child: _OverlayCircleButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            iconSize: 18,
            iconColor: isFavorite ? AppColors.primary : Colors.white,
            onTap: onToggleFavorite,
          ),
        ),
      ],
    );
  }
}

/// Same translucent circular chrome for both the back button and the
/// favorite button.
class _OverlayCircleButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback? onTap;

  const _OverlayCircleButton({required this.icon, required this.iconSize, this.iconColor = Colors.white, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final VenueCategory category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: ChatLightColors.cardSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(venueCategoryIcon(category), size: 13, color: ChatLightColors.inkSoft),
          const SizedBox(width: 5),
          Text(
            venueCategoryLabel(loc, category),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isOpen;

  const _StatusPill({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = isOpen ? ChatLightColors.onlineGreen : ChatLightColors.inkFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
      child: Text(
        isOpen ? loc.venueOpenNowLabel : loc.venueClosedNowLabel,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _WeeklySchedule extends StatelessWidget {
  final OpeningHours hours;

  const _WeeklySchedule({required this.hours});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (hours.is24h) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(loc.venueHours24Label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
          ],
        ),
      );
    }

    final today = DateTime.now().weekday;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var weekday = 1; weekday <= 7; weekday++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      _weekdayLabel(loc, weekday),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: weekday == today ? FontWeight.w800 : FontWeight.w500,
                        color: weekday == today ? AppColors.primary : ChatLightColors.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      hours.schedule[weekday] == null
                          ? loc.venueClosedNowLabel
                          : '${hours.schedule[weekday]!.open} – ${hours.schedule[weekday]!.close}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: weekday == today ? FontWeight.w700 : FontWeight.w500,
                        color: hours.schedule[weekday] == null ? ChatLightColors.inkFaint : ChatLightColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _weekdayLabel(AppLocalizations loc, int weekday) {
    return switch (weekday) {
      1 => loc.venueWeekdayMon,
      2 => loc.venueWeekdayTue,
      3 => loc.venueWeekdayWed,
      4 => loc.venueWeekdayThu,
      5 => loc.venueWeekdayFri,
      6 => loc.venueWeekdaySat,
      _ => loc.venueWeekdaySun,
    };
  }
}

class _MiniMap extends ConsumerWidget {
  final Venue venue;

  const _MiniMap({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapLocationSettings = ref.watch(mapLocationSettingsProvider).valueOrNull ?? const MapLocationSettings();
    final center = LatLng(venue.lat, venue.lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        child: IgnorePointer(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 15.5),
            mapType: toGoogleMapType(mapLocationSettings.mapType),
            markers: {Marker(markerId: const MarkerId('venue'), position: center)},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
        ),
      ),
    );
  }
}

class _DirectionsRow extends StatelessWidget {
  final Venue venue;

  const _DirectionsRow({required this.venue});

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final lat = venue.lat;
    final lng = venue.lng;

    return Row(
      children: [
        Expanded(
          child: _DirectionsButton(
            icon: Icons.map_outlined,
            label: loc.venueDirectionsGoogleMaps,
            onTap: () => _open('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DirectionsButton(
            icon: Icons.map_outlined,
            label: loc.venueDirectionsAppleMaps,
            onTap: () => _open('https://maps.apple.com/?daddr=$lat,$lng'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DirectionsButton(
            icon: Icons.navigation_outlined,
            label: loc.venueDirectionsWaze,
            onTap: () => _open('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
          ),
        ),
      ],
    );
  }
}

class _DirectionsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DirectionsButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
