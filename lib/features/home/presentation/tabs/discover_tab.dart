import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_formatter.dart';
import '../../../../core/utils/distance_unit.dart';
import '../../../../core/widgets/premium_upsell_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/avatar_pin_marker.dart';
import '../../../auth/presentation/widgets/country_dial_code.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../../chat/presentation/screens/chat_conversation_screen.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../location/domain/country_bounds.dart';
import '../../../location/domain/location_failure.dart';
import '../../../location/domain/nearby_user.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../offers/presentation/screens/create_offer_screen.dart';
import '../../../offers/presentation/screens/my_offers_screen.dart';
import '../../../events/presentation/widgets/venue_event_banner.dart';
import '../../../offers/presentation/widgets/offer_list_view.dart';
import '../../../premium/presentation/providers/premium_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../../settings/map_location/domain/entities/map_location_settings.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/domain/venue_open_status.dart';
import '../../../venues/presentation/providers/venue_providers.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart';
import '../../../venues/presentation/screens/my_venues_screen.dart';
import '../../../venues/presentation/screens/venue_premium_info_screen.dart';
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../../../venues/presentation/widgets/venue_filter_sheet.dart';
import '../../../venues/presentation/widgets/venue_star_rating.dart';

enum _DiscoverView { map, places, offers }

class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  GoogleMapController? _mapController;
  _DiscoverView _view = _DiscoverView.map;

  // Keyed by 'userId|photoUrl' so a changed photo invalidates its own
  // entry rather than showing a stale avatar. Never evicted — bounded
  // by how many distinct nearby users this session ever sees, which is
  // small enough that holding onto them for the widget's lifetime is
  // cheaper than re-rendering the same bitmap on every rebuild.
  final Map<String, BitmapDescriptor> _avatarMarkerCache = {};
  final Set<String> _avatarMarkerPending = {};

  BitmapDescriptor? _avatarMarkerFor(NearbyUser user) => _avatarMarker(user.id, user.photoUrl);

  /// Shared by both the "me" marker and every nearby-user marker — [id]
  /// just needs to be stable per person (their uid works for both).
  BitmapDescriptor? _avatarMarker(String id, String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;

    final cacheKey = '$id|$photoUrl';
    final cached = _avatarMarkerCache[cacheKey];
    if (cached != null) return cached;

    if (_avatarMarkerPending.add(cacheKey)) {
      AvatarPinMarker.build(photoUrl: photoUrl).then((marker) {
        if (!mounted) return;
        setState(() => _avatarMarkerCache[cacheKey] = marker);
      }).catchError((_) {
        // Network hiccup/unreadable image — falls back to the default
        // pin below for this build; the next rebuild retries since the
        // key never got cached (only removed from pending).
      }).whenComplete(() => _avatarMarkerPending.remove(cacheKey));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // Keeps `users/{uid}.discoverRadiusMode`/`discoverRadiusKm` in sync
    // with the picker below — see the provider's own doc comment for
    // why this lives here rather than in LocationController.
    ref.watch(discoverRadiusPersistenceProvider);
    final locationState = ref.watch(locationControllerProvider);
    final nearbyUsers = ref.watch(nearbyUsersProvider);
    final hasBusinessAccess = ref.watch(profileControllerProvider).hasBusinessAccess;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(child: Text(loc.discoverTitle, style: AppTextStyles.pageTitle)),
                if (_view == _DiscoverView.map)
                  IconButton(
                    tooltip: loc.genderFilterTooltip,
                    onPressed: () => _showGenderFilterSheet(context),
                    icon: const Icon(Icons.filter_alt_outlined, color: AppColors.textSecondary),
                  ),
                if (_view == _DiscoverView.places && hasBusinessAccess) ...[
                  IconButton(
                    tooltip: loc.venueMyVenuesTooltip,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyVenuesScreen()),
                    ),
                    icon: const Icon(Icons.storefront_outlined, color: AppColors.textSecondary),
                  ),
                  IconButton(
                    tooltip: loc.venueAddButtonTooltip,
                    onPressed: () async {
                      if (!await requireVerified(context, ref)) return;
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateVenueScreen()),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary),
                  ),
                ],
                if (_view == _DiscoverView.offers && hasBusinessAccess) ...[
                  IconButton(
                    tooltip: loc.offerMyOffersTooltip,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyOffersScreen()),
                    ),
                    icon: const Icon(Icons.local_offer_outlined, color: AppColors.textSecondary),
                  ),
                  IconButton(
                    tooltip: loc.offerAddButtonTooltip,
                    onPressed: () async {
                      if (!await requireVerified(context, ref)) return;
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateOfferScreen()),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ViewSwitcher(
              view: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _view == _DiscoverView.map
                ? locationState.when(
                    loading: () => _StatusMessage(
                      icon: Icons.location_searching,
                      title: loc.locationSearchingTitle,
                      subtitle: loc.locationSearchingSubtitle,
                      showSpinner: true,
                    ),
                    error: (error, _) => _buildError(context, error),
                    data: (position) => _buildMap(position, nearbyUsers),
                  )
                // Venue/offer visibility is radius-scoped too (see
                // venue_providers.dart/offer_providers.dart, both watch
                // selectedDiscoverModeProvider) — the picker stays visible
                // here for the same reason it does over the map, just
                // pinned below the list instead of over a GoogleMap.
                : Stack(
                    children: [
                      _view == _DiscoverView.places ? const _VenueListView() : const OfferListView(),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: _RadiusOptionsRow(
                            onSelected: (newSelection) async {
                              if (!await requireVerified(context, ref)) return;
                              if (!context.mounted) return;
                              ref.read(selectedDiscoverModeProvider.notifier).state = newSelection;
                            },
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

  Widget _buildError(BuildContext context, Object error) {
    final loc = AppLocalizations.of(context);

    if (error is LocationException) {
      switch (error.type) {
        case LocationFailure.serviceDisabled:
          return _StatusMessage(
            icon: Icons.location_off_outlined,
            title: loc.locationServiceDisabledTitle,
            subtitle: loc.locationServiceDisabledSubtitle,
            actionLabel: loc.actionOpenSettings,
            onAction: () => Geolocator.openLocationSettings(),
          );
        case LocationFailure.permissionDenied:
          return _StatusMessage(
            icon: Icons.pin_drop_outlined,
            title: loc.locationPermissionDeniedTitle,
            subtitle: loc.locationPermissionDeniedSubtitle,
            actionLabel: loc.actionRetry,
            onAction: () => ref.read(locationControllerProvider.notifier).refresh(),
          );
        case LocationFailure.permissionDeniedForever:
          return _StatusMessage(
            icon: Icons.settings_outlined,
            title: loc.locationPermissionDeniedForeverTitle,
            subtitle: loc.locationPermissionDeniedForeverSubtitle,
            actionLabel: loc.actionOpenAppSettings,
            onAction: () => Geolocator.openAppSettings(),
          );
      }
    }

    return _StatusMessage(
      icon: Icons.error_outline,
      title: loc.errorTitle,
      subtitle: '$error',
      actionLabel: loc.actionRetry,
      onAction: () => ref.read(locationControllerProvider.notifier).refresh(),
    );
  }

  Widget _buildMap(Position position, List<NearbyUser> nearbyUsers) {
    final loc = AppLocalizations.of(context);
    final center = LatLng(position.latitude, position.longitude);
    final selection = ref.watch(selectedDiscoverModeProvider);
    final mapLocationSettings = ref.watch(mapLocationSettingsProvider).valueOrNull ?? const MapLocationSettings();
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final myPhotoUrl = ref.watch(profileControllerProvider).photoUrl;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: center,
        icon: (myUid == null ? null : _avatarMarker(myUid, myPhotoUrl)) ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 1),
        infoWindow: InfoWindow(title: loc.meMarkerLabel),
      ),
      for (final u in nearbyUsers)
        Marker(
          markerId: MarkerId(u.id),
          position: LatLng(u.lat, u.lng),
          icon: _avatarMarkerFor(u) ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 1),
          onTap: () => _showUserCard(context, position, u),
        ),
    };

    // The initial camera always frames the free/default distance
    // ring around the device's own position — Ölkə/Dünya only kick in
    // once the user actively picks one (see _applySelection), animated
    // from whatever the camera currently shows.
    final initialZoom = _zoomForRadiusKm(selection.km ?? 1.0);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: initialZoom),
          mapType: toGoogleMapType(mapLocationSettings.mapType),
          onMapCreated: (controller) => _mapController = controller,
          markers: markers,
          circles: selection.mode == DiscoverRadiusMode.distance
              ? {
                  Circle(
                    circleId: const CircleId('radius'),
                    center: center,
                    radius: selection.km! * 1000,
                    fillColor: AppColors.primary.withOpacity(0.08),
                    strokeColor: AppColors.primary.withOpacity(0.4),
                    strokeWidth: 1,
                  ),
                }
              : const {},
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          // Explicit rather than relying on the plugin's defaults (which
          // are already true) — makes it unambiguous that nothing in this
          // screen intentionally restricts pan/zoom/rotate.
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          onCameraMove: (_) {},
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: FloatingActionButton(
                    heroTag: 'discoverMyLocationFab',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    onPressed: () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(center, _zoomForRadiusKm(selection.km ?? 1.0)),
                      );
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                _RadiusOptionsRow(
                  onSelected: (newSelection) async {
                    if (!await requireVerified(context, ref)) return;
                    if (!context.mounted) return;
                    _applySelection(newSelection, center);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _zoomForRadiusKm(double radiusKm) {
    if (radiusKm <= 0.1) return 17;
    if (radiusKm <= 0.5) return 15.5;
    if (radiusKm <= 1) return 14.5;
    if (radiusKm <= 5) return 13;
    if (radiusKm <= 10) return 12;
    return 10.5;
  }

  /// Commits [selection] to state and animates the camera to match:
  /// a normal zoom level for a distance ring, fit-to-bounds for the
  /// user's own country, or a whole-earth minimum zoom for Dünya üzrə.
  void _applySelection(DiscoverRadiusSelection selection, LatLng center) {
    ref.read(selectedDiscoverModeProvider.notifier).state = selection;

    switch (selection.mode) {
      case DiscoverRadiusMode.distance:
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(center, _zoomForRadiusKm(selection.km!)));
      case DiscoverRadiusMode.country:
        final country = ref.read(profileControllerProvider).country;
        final bounds = country == null ? null : kCountryBounds[country];
        if (bounds == null) return;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(bounds.swLat, bounds.swLng),
              northeast: LatLng(bounds.neLat, bounds.neLng),
            ),
            24,
          ),
        );
      case DiscoverRadiusMode.world:
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(const LatLng(20, 0), 1.5));
    }
  }

  void _showUserCard(BuildContext context, Position myPosition, NearbyUser user) {
    final loc = AppLocalizations.of(context);
    final displayName = user.name.isEmpty ? loc.defaultUserName : user.name;
    final distanceMeters = user.distanceMeters;
    final distanceUnit = ref.read(mapLocationSettingsProvider).valueOrNull?.distanceUnit ?? DistanceUnit.km;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          uid: user.id,
                          initialName: displayName,
                          initialPhotoUrl: user.photoUrl,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.card,
                          image: user.photoUrl != null
                              ? DecorationImage(image: NetworkImage(user.photoUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: user.photoUrl == null
                            ? const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 30)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isRecentlyActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              formatDistance(loc, distanceMeters, distanceUnit),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (!await requireVerified(context, ref)) return;
                          if (!context.mounted) return;
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(
                                otherUid: user.id,
                                otherName: displayName,
                                otherPhotoUrl: user.photoUrl,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.onAccent),
                        label: Text(loc.startChatButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGenderFilterSheet(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final current = ref.read(selectedGenderFilterProvider);
    final isPremium = ref.read(isPremiumProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(loc.genderFilterSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                // "Hamı" stays free — only picking a specific gender is
                // VIP-only (see [selectedGenderFilterProvider]'s doc
                // comment), so the unfiltered default is never locked.
                for (final option in [
                  (GenderFilter.all, loc.genderFilterAll, false),
                  (GenderFilter.male, loc.genderFilterMale, true),
                  (GenderFilter.female, loc.genderFilterFemale, true),
                ])
                  ListTile(
                    title: Row(
                      children: [
                        Text(option.$2, style: AppTextStyles.body.copyWith(fontSize: 15.5)),
                        if (option.$3 && !isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.workspace_premium_outlined, size: 14, color: AppColors.gold),
                        ],
                      ],
                    ),
                    leading: Icon(
                      option.$1 == current ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: option.$1 == current ? AppColors.primary : AppColors.textMuted,
                    ),
                    onTap: () {
                      if (option.$3 && !isPremium) {
                        showPremiumUpsellSheet(
                          sheetContext,
                          title: loc.premiumUpsellGenderTitle,
                          message: loc.premiumUpsellGenderMessage,
                        );
                        return;
                      }
                      ref.read(selectedGenderFilterProvider.notifier).state = option.$1;
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatRadius(double km) {
  return km >= 1 ? '${km.toStringAsFixed(0)} km' : '${(km * 1000).toStringAsFixed(0)} m';
}

class _ViewSwitcher extends StatelessWidget {
  final _DiscoverView view;
  final ValueChanged<_DiscoverView> onChanged;

  const _ViewSwitcher({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _SwitcherOption(
            label: loc.viewSwitcherPeopleLabel,
            icon: Icons.people_alt_outlined,
            selected: view == _DiscoverView.map,
            onTap: () => onChanged(_DiscoverView.map),
          ),
          const SizedBox(width: 4),
          _SwitcherOption(
            label: loc.viewSwitcherPlacesLabel,
            icon: Icons.storefront_outlined,
            selected: view == _DiscoverView.places,
            onTap: () => onChanged(_DiscoverView.places),
          ),
          const SizedBox(width: 4),
          _SwitcherOption(
            label: loc.viewSwitcherOffersLabel,
            icon: Icons.local_offer_outlined,
            selected: view == _DiscoverView.offers,
            onTap: () => onChanged(_DiscoverView.offers),
          ),
        ],
      ),
    );
  }
}

class _SwitcherOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SwitcherOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentColor = selected ? AppColors.onAccent : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: contentColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: contentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every radius pill (default row AND the "Daha çox" panel) shares this
/// one height/radius/typography envelope — 80% of the pre-redesign
/// 60px ([_kLegacyRadiusOptionHeight]), reached entirely by shrinking
/// padding/spacing, not font sizes, so the distance label and the
/// people-count stay just as readable.
const double _kLegacyRadiusOptionHeight = 60;
const double _kRadiusOptionHeight = _kLegacyRadiusOptionHeight * 0.8;

class _RadiusOptionsRow extends ConsumerWidget {
  final ValueChanged<DiscoverRadiusSelection> onSelected;

  const _RadiusOptionsRow({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final selection = ref.watch(selectedDiscoverModeProvider);
    final counts = ref.watch(radiusUserCountsProvider);

    // Whichever of Ölkə/Dünya/5/10/30 km is active lives behind "Daha
    // çox", so none of the 3 always-visible pills can show it as
    // selected — without this, picking one of those left the whole row
    // looking unselected, which read as "the tap did nothing" even
    // though the radius had actually changed underneath.
    final isDefaultSelection =
        selection.mode == DiscoverRadiusMode.distance && kDefaultRadiusOptionsKm.contains(selection.km);
    final moreButtonLabel = isDefaultSelection
        ? null
        : switch (selection.mode) {
            DiscoverRadiusMode.distance => _formatRadius(selection.km!),
            DiscoverRadiusMode.country => loc.privacyRadiusCountryLabel,
            DiscoverRadiusMode.world => loc.privacyRadiusWorldLabel,
          };

    return Container(
      width: double.infinity,
      color: AppColors.backgroundDark,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      // A fixed-width Row of Expanded buttons so the default-row options
      // always split the available width evenly and stay put — no
      // scrolling, no per-option width drift as labels change length.
      child: Row(
        children: [
          for (var i = 0; i < kDefaultRadiusOptionsKm.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _RadiusOption(
                km: kDefaultRadiusOptionsKm[i],
                selected: selection.mode == DiscoverRadiusMode.distance && selection.km == kDefaultRadiusOptionsKm[i],
                locked: false,
                count: counts[kDefaultRadiusOptionsKm[i]] ?? 0,
                onTap: () => onSelected(DiscoverRadiusSelection.distance(kDefaultRadiusOptionsKm[i])),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: _MoreRadiusButton(
              selected: !isDefaultSelection,
              label: moreButtonLabel,
              onTap: () => _showMoreRadiusSheet(context, onSelected),
            ),
          ),
        ],
      ),
    );
  }
}

void _showMoreRadiusSheet(BuildContext context, ValueChanged<DiscoverRadiusSelection> onSelected) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    // Soft slide-up/fade — showModalBottomSheet's default transition —
    // is exactly the "yumşaq slide/fade animasiya" the spec asks for,
    // so no custom transition needed here.
    builder: (_) => _MoreRadiusPanel(onSelected: onSelected),
  );
}

/// Same pill envelope as [_RadiusOption] — turns "selected" (teal fill,
/// [label] replacing the generic "Daha çox" text) whenever the active
/// radius is one of the options living inside the sheet this opens
/// (5/10/30 km, Ölkə, Dünya), so there's always a persistent, visible
/// answer to "what's selected right now" even though none of the 3
/// always-visible pills can show it themselves.
class _MoreRadiusButton extends StatelessWidget {
  final bool selected;
  final String? label;
  final VoidCallback onTap;

  const _MoreRadiusButton({required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final textColor = selected ? AppColors.onAccent : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: double.infinity,
        height: _kRadiusOptionHeight,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.transparent : AppColors.divider),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label ?? loc.radiusMoreButtonLabel,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_outlined, size: 16, color: textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Daha çox" panel: 5/10/30 km (free, same distance-filter logic
/// as the row above, just a bigger radius) plus the two VIP-only
/// non-distance modes, Ölkə üzrə and Dünya üzrə (real Firestore
/// queries — see `nearbyUsersProvider` — plus a matching map camera
/// move once selected).
class _MoreRadiusPanel extends ConsumerWidget {
  final ValueChanged<DiscoverRadiusSelection> onSelected;

  const _MoreRadiusPanel({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final selection = ref.watch(selectedDiscoverModeProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final counts = ref.watch(radiusUserCountsProvider);
    final myCountry = ref.watch(profileControllerProvider).country;
    final countryFlag = flagForCountryName(myCountry);

    void handleLockedTap() {
      showPremiumUpsellSheet(
        context,
        title: loc.premiumUpsellRadiusTitle,
        message: loc.premiumUpsellRadiusMessage,
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(loc.radiusMorePanelTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < kExtraRadiusOptionsKm.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _RadiusOption(
                      km: kExtraRadiusOptionsKm[i],
                      selected: selection.mode == DiscoverRadiusMode.distance &&
                          selection.km == kExtraRadiusOptionsKm[i],
                      locked: false,
                      count: counts[kExtraRadiusOptionsKm[i]] ?? 0,
                      onTap: () {
                        onSelected(DiscoverRadiusSelection.distance(kExtraRadiusOptionsKm[i]));
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SpecialRadiusOption(
                    selected: selection.mode == DiscoverRadiusMode.country,
                    locked: !isPremium,
                    onTap: () {
                      if (!isPremium) {
                        handleLockedTap();
                        return;
                      }
                      onSelected(const DiscoverRadiusSelection.country());
                      Navigator.pop(context);
                    },
                    child: countryFlag != null
                        ? Text(countryFlag, style: const TextStyle(fontSize: 20))
                        : const Icon(Icons.flag_outlined, color: AppColors.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SpecialRadiusOption(
                    selected: selection.mode == DiscoverRadiusMode.world,
                    locked: !isPremium,
                    onTap: () {
                      if (!isPremium) {
                        handleLockedTap();
                        return;
                      }
                      onSelected(const DiscoverRadiusSelection.world());
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.public_outlined, color: AppColors.textSecondary, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Textless variant of [_RadiusOption] for Ölkə üzrə/Dünya üzrə — same
/// pill envelope, just a single centered icon/flag instead of a
/// distance label + count.
class _SpecialRadiusOption extends StatelessWidget {
  final Widget child;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _SpecialRadiusOption({
    required this.child,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: _kRadiusOptionHeight,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (locked ? AppColors.gold.withValues(alpha: 0.35) : AppColors.divider),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            child,
            if (locked)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.workspace_premium_outlined, size: 12, color: AppColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadiusOption extends StatelessWidget {
  final double km;
  final bool selected;
  final bool locked;
  final int count;
  final VoidCallback onTap;

  const _RadiusOption({
    required this.km,
    required this.selected,
    required this.locked,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? AppColors.onAccent : (locked ? AppColors.white : AppColors.textSecondary);
    final iconColor = selected ? AppColors.onAccent.withValues(alpha: 0.75) : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: double.infinity,
        height: _kRadiusOptionHeight,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (locked ? AppColors.gold.withValues(alpha: 0.35) : AppColors.divider),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (locked) ...[
                    const Icon(Icons.workspace_premium_outlined, size: 12, color: AppColors.gold),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _formatRadius(km),
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: labelColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _PeopleCountIndicator(count: count, color: iconColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the old "{count} nəfər" text with the count plus a small
/// overlapping cluster of head-and-shoulders glyphs (Icons.person is a
/// bust silhouette, not a full-body figure) in dark green.
class _PeopleCountIndicator extends StatelessWidget {
  final int count;
  final Color color;

  const _PeopleCountIndicator({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    const iconSize = 12.0;
    const overlap = 7.0;
    const iconCount = 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: overlap * (iconCount - 1) + iconSize,
          height: iconSize,
          child: Stack(
            children: [
              for (var i = 0; i < iconCount; i++)
                Positioned(
                  left: i * overlap,
                  child: Icon(Icons.person, size: iconSize, color: color),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showSpinner;

  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 0),
                ],
              ),
              child: showSpinner
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(icon, color: AppColors.textSecondary, size: 42),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(height: 1.5),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(minimumSize: const Size(220, 50)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kəşf et → Məkanlar list — reuses the exact same radius selection as
/// İnsanlar ([nearbyVenuesProvider] watches the same
/// [selectedDiscoverModeProvider]), so switching tabs never resets the
/// user's chosen distance. One-shot geohash-range fetch, not a live
/// stream — see [VenueRepository.fetchVenuesWithinRadius].
///
/// This content area is a deliberate light-theme exception like the
/// chat screens ([ChatLightBackground]/[ChatLightColors]) — the rest
/// of Kəşf et (title, İnsanlar/Məkanlar/Təkliflər switcher) stays
/// dark, only the venue list itself switches, matching the approved
/// mockup.
/// Collapses the Azerbaijani/Turkish İ/I/ı family down to plain ASCII
/// 'i' — same fix, same reasoning as `chats_tab.dart`'s/`offer_list_view.dart`'s
/// own private `_azSearchKey` (duplicated rather than shared).
String _azVenueSearchKey(String value) {
  return value.replaceAll('İ', 'i').replaceAll('I', 'i').replaceAll('ı', 'i').toLowerCase();
}

class _VenueListView extends ConsumerStatefulWidget {
  const _VenueListView();

  @override
  ConsumerState<_VenueListView> createState() => _VenueListViewState();
}

class _VenueListViewState extends ConsumerState<_VenueListView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final selected = ref.read(selectedVenueCategoryFilterProvider);
    final result = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: ChatLightColors.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => VenueFilterSheet(selected: selected),
    );
    if (!mounted) return;

    // null here is "dismissed without choosing" — see
    // ClearVenueCategoryFilter's doc comment for why an explicit
    // "Hamısı" tap can't share that same null result.
    if (result == null) return;
    if (result is ClearVenueCategoryFilter) {
      ref.read(selectedVenueCategoryFilterProvider.notifier).state = null;
    } else if (result is VenueCategory) {
      ref.read(selectedVenueCategoryFilterProvider.notifier).state = result;
    }
  }

  List<VenueWithDistance> _visible(List<VenueWithDistance> all, AppLocalizations loc) {
    if (_query.isEmpty) return all;
    final q = _azVenueSearchKey(_query);
    return all.where((item) {
      final venue = item.venue;
      return _azVenueSearchKey(venue.name).contains(q) ||
          _azVenueSearchKey(venue.address).contains(q) ||
          _azVenueSearchKey(venueCategoryLabel(loc, venue.category)).contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final venuesAsync = ref.watch(nearbyVenuesProvider);
    final distanceUnit = ref.watch(mapLocationSettingsProvider).valueOrNull?.distanceUnit ?? DistanceUnit.km;
    final selectedCategory = ref.watch(selectedVenueCategoryFilterProvider);

    return Stack(
      children: [
        const ChatLightBackground(),
        Positioned.fill(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: _VenueSearchField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  onFilterTap: _openFilterSheet,
                  filterActive: selectedCategory != null,
                ),
              ),
              Expanded(
                child: venuesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary),
                  ),
                  error: (error, _) => _VenueLightStatusMessage(
                    icon: Icons.error_outline,
                    title: loc.errorTitle,
                    subtitle: '$error',
                    actionLabel: loc.actionRetry,
                    onAction: () => ref.invalidate(nearbyVenuesProvider),
                  ),
                  data: (venues) {
                    final visible = _visible(venues, loc);
                    if (visible.isEmpty) {
                      return _VenueLightStatusMessage(
                        icon: Icons.storefront_outlined,
                        title: loc.venuesEmptyTitle,
                        subtitle: loc.venuesEmptySubtitle,
                      );
                    }
                    return ListView.separated(
                      // Extra bottom padding (vs. the map view's plain 24)
                      // so the last card doesn't sit under the persistent
                      // _RadiusOptionsRow now pinned below this list too.
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _VenueCard(item: visible[index], loc: loc, distanceUnit: distanceUnit),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final bool filterActive;

  const _VenueSearchField({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
    required this.filterActive,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: loc.venuesSearchHint,
                hintStyle: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14.5),
                prefixIcon: const Icon(Icons.search, color: ChatLightColors.inkFaint, size: 21),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: ChatLightColors.inkFaint, size: 18),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onFilterTap,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: filterActive ? AppColors.primary : ChatLightColors.inkSoft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Photo/distance-badge/name/category/address layout matching the
/// approved reference mockup, styled with [ChatLightColors] for
/// consistency with the rest of the light-theme venue screens.
/// Deliberately no star rating (no review system exists yet — this
/// app never shows fabricated numbers).
class _VenueCard extends ConsumerWidget {
  final VenueWithDistance item;
  final AppLocalizations loc;
  final DistanceUnit distanceUnit;

  const _VenueCard({required this.item, required this.loc, required this.distanceUnit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = item.venue;
    final isLiked = ref.watch(isVenueLikedByMeProvider(venue.id)).valueOrNull ?? false;
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && venue.isOwnedBy(currentUid);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VenueProfileScreen(venueId: venue.id)),
        ),
        child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: venue.photoUrl != null
                          ? Image.network(venue.photoUrl!, fit: BoxFit.cover)
                          : Container(
                              color: ChatLightColors.cardSurface,
                              alignment: Alignment.center,
                              child: Icon(venueCategoryIcon(venue.category), color: ChatLightColors.inkSoft, size: 28),
                            ),
                    ),
                  ),
                  Positioned(
                    left: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: ChatLightColors.contourLine.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatDistance(loc, item.distanceMeters, distanceUnit),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 26, top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              venue.name,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (venue.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 15, color: AppColors.primary),
                          ],
                          if (venue.isPremium) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.workspace_premium_rounded, size: 15, color: AppColors.gold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(venueCategoryIcon(venue.category), size: 13, color: ChatLightColors.inkSoft),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              venueCategoryLabel(loc, venue.category),
                              style: TextStyle(fontSize: 12, color: ChatLightColors.inkSoft, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          VenueRatingBadge(
                            rating: venue.rating,
                            starSize: 11,
                            textStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _OpenStatusBadge(isOpen: isVenueOpenNow(venue.openingHours, DateTime.now())),
                          const SizedBox(width: 6),
                          if (!venue.openingHours.is24h)
                            Text(
                              _hoursSummary(venue.openingHours),
                              style: TextStyle(fontSize: 12, color: ChatLightColors.inkFaint, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                        ],
                      ),
                      if (venue.address.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 12.5, color: ChatLightColors.inkFaint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                venue.address,
                                style: TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      VenueEventBanner(venueId: venue.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              // A venue's prominence among OTHER people's votes is
              // governed entirely by user likes — but the owner can't
              // like their own venue (that would be self-inflation, the
              // same reason they can't check in at their own venue), so
              // the owner gets a premium-upsell menu here instead.
              onTap: isOwner
                  ? () => _openVenuePremiumMenu(context, venue)
                  : () => ref.read(venueControllerProvider).toggleLike(venue.id, isCurrentlyLiked: isLiked),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: ChatLightColors.inkFaint.withValues(alpha: 0.18)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: isOwner
                    ? Tooltip(
                        message: venue.isPremium ? loc.venuePremiumMenuItemActive : loc.venuePremiumMenuItem,
                        child: venue.isPremium
                            ? const Icon(Icons.workspace_premium_rounded, size: 17, color: AppColors.gold)
                            : const Icon(Icons.more_vert_rounded, size: 17, color: ChatLightColors.inkSoft),
                      )
                    : AnimatedScale(
                        scale: isLiked ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 15,
                          color: isLiked ? AppColors.primary : ChatLightColors.inkSoft,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _openVenuePremiumMenu(BuildContext context, Venue venue) {
    if (venue.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VenuePremiumInfoScreen(premiumSince: venue.premiumSince)),
      );
      return;
    }
    final sheetLoc = AppLocalizations.of(context);
    showPremiumUpsellSheet(
      context,
      title: sheetLoc.venuePremiumMenuItem,
      message: sheetLoc.venuePremiumUpsellMessage,
    );
  }

  String _hoursSummary(OpeningHours hours) {
    final today = hours.schedule[DateTime.now().weekday];
    if (today == null) return loc.venueClosedNowLabel;
    return '${today.open}–${today.close}';
  }
}

/// Client-side-computed open/closed pill — see [isVenueOpenNow]. No
/// external API, no live ticking; recomputed whenever the card
/// rebuilds, which is enough for a status that only flips on the hour
/// boundaries the venue itself configured.
class _OpenStatusBadge extends StatelessWidget {
  final bool isOpen;

  const _OpenStatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = isOpen ? ChatLightColors.onlineGreen : ChatLightColors.inkFaint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOpen ? loc.venueOpenNowLabel : loc.venueClosedNowLabel,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Light-theme counterpart of [_StatusMessage] — same layout/purpose,
/// just recolored for the venue list's [ChatLightBackground] rather
/// than the app's dark theme.
class _VenueLightStatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _VenueLightStatusMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)],
              ),
              child: Icon(icon, color: ChatLightColors.inkSoft, size: 42),
            ),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ChatLightColors.inkSoft, height: 1.5),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: ChatLightColors.contourLine,
                  minimumSize: const Size(220, 50),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
