import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/data/countries_cities.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../settings/map_location/domain/entities/map_location_settings.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';

/// Full-screen "drop a pin" map picker for a venue's exact location —
/// same drop-a-pin UX as `events`' `LocationPickerScreen`, plus a
/// reverse-geocoded, display-only address readout under the confirm
/// button (per spec: the address is never hand-typed for a venue).
/// Pops with a `(LatLng, String address, String? country)` record on
/// confirm, or null if the user backs out.
class VenueLocationPickerScreen extends ConsumerStatefulWidget {
  final LatLng? initialPosition;

  const VenueLocationPickerScreen({super.key, this.initialPosition});

  @override
  ConsumerState<VenueLocationPickerScreen> createState() =>
      _VenueLocationPickerScreenState();
}

class _VenueLocationPickerScreenState
    extends ConsumerState<VenueLocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _picked;
  String? _address;
  String? _country;
  bool _resolvingAddress = false;
  int _geocodeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialPosition;
    if (_picked != null) _resolveAddress(_picked!);
  }

  /// Debounced by [_geocodeRequestId] — a fast drag can fire several
  /// pin moves before the first lookup returns; only the response
  /// matching the LATEST request is ever applied, so the address never
  /// flickers back to a stale/earlier pin's result.
  Future<void> _resolveAddress(LatLng position) async {
    final requestId = ++_geocodeRequestId;
    setState(() => _resolvingAddress = true);

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted || requestId != _geocodeRequestId) return;
      final address = placemarks.isEmpty
          ? null
          : _formatPlacemark(placemarks.first);
      // The device geocoder returns whatever spelling it feels like
      // (e.g. "Azerbaycan" without the "ə") — normalized onto
      // `kCountryNames`' exact spelling so this string-equals
      // `UserProfile.country` (picked from that same list) for
      // country-scoped queries like `_countryCandidatesProvider`.
      final country = canonicalCountryName(
        placemarks.isEmpty ? null : placemarks.first.country,
      );
      setState(() {
        _address = address;
        _country = (country?.isNotEmpty ?? false) ? country : null;
        _resolvingAddress = false;
      });
    } catch (_) {
      if (!mounted || requestId != _geocodeRequestId) return;
      setState(() {
        _address = null;
        _country = null;
        _resolvingAddress = false;
      });
    }
  }

  String _formatPlacemark(Placemark p) {
    final street = (p.thoroughfare?.isNotEmpty ?? false)
        ? p.thoroughfare!
        : (p.street ?? '');
    final houseNumber = p.subThoroughfare ?? '';
    final area = (p.subLocality?.isNotEmpty ?? false)
        ? p.subLocality!
        : (p.locality ?? '');

    final streetLine = [
      street,
      houseNumber,
    ].where((s) => s.isNotEmpty).join(' ');
    final parts = [streetLine, area].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.join(', ');
  }

  void _onPick(LatLng position) {
    setState(() => _picked = position);
    _resolveAddress(position);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final myPosition = ref.watch(locationControllerProvider).valueOrNull;
    final mapLocationSettings =
        ref.watch(mapLocationSettingsProvider).valueOrNull ??
        const MapLocationSettings();
    final center =
        widget.initialPosition ??
        (myPosition != null
            ? LatLng(myPosition.latitude, myPosition.longitude)
            : const LatLng(40.4093, 49.8671));

    _picked ??= center;

    final canConfirm = _picked != null && !_resolvingAddress;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppColors.white,
          ),
        ),
        title: Text(loc.venueLocationPickerTitle),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 16),
            mapType: toGoogleMapType(mapLocationSettings.mapType),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onPick,
            markers: {
              if (_picked != null)
                Marker(
                  markerId: const MarkerId('picked'),
                  position: _picked!,
                  draggable: true,
                  onDragEnd: _onPick,
                ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
          Positioned(
            right: 16,
            bottom: 168,
            child: FloatingActionButton(
              heroTag: 'venueLocationPickerMyLocationFab',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              elevation: 2,
              onPressed: myPosition == null
                  ? null
                  : () {
                      final here = LatLng(
                        myPosition.latitude,
                        myPosition.longitude,
                      );
                      _onPick(here);
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(here),
                      );
                    },
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  loc.venueLocationPickerHint,
                  style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _resolvingAddress
                                ? Text(
                                    loc.venueLocationResolvingAddress,
                                    style: AppTextStyles.caption,
                                  )
                                : Text(
                                    (_address == null || _address!.isEmpty)
                                        ? loc.venueLocationAddressUnavailable
                                        : _address!,
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: canConfirm
                          ? () => Navigator.pop(context, (
                              _picked!,
                              _address ?? '',
                              _country,
                            ))
                          : null,
                      child: Text(loc.venueLocationPickerConfirmButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
