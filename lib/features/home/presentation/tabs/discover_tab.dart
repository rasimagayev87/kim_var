import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../location/domain/location_failure.dart';
import '../../../location/domain/nearby_user.dart';
import '../../../location/presentation/providers/location_providers.dart';

class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationControllerProvider);
    final nearbyUsers = ref.watch(nearbyUsersProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kəşf et',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white),
                ),
                GestureDetector(
                  onTap: () => _showRadiusSheet(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatRadius(ref.watch(selectedRadiusKmProvider))}',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: locationState.when(
              loading: () => const _StatusMessage(
                icon: Icons.location_searching,
                title: 'Lokasiya müəyyən edilir...',
                subtitle: 'Bir neçə saniyə çəkə bilər.',
                showSpinner: true,
              ),
              error: (error, _) => _buildError(error),
              data: (position) => _buildMap(position, nearbyUsers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    if (error is LocationException) {
      switch (error.type) {
        case LocationFailure.serviceDisabled:
          return _StatusMessage(
            icon: Icons.location_off_outlined,
            title: 'Lokasiya xidməti sönülüdür',
            subtitle: 'Yaxınlıqdakı insanları görmək üçün cihazında lokasiyanı aç.',
            actionLabel: 'Ayarları aç',
            onAction: () => Geolocator.openLocationSettings(),
          );
        case LocationFailure.permissionDenied:
          return _StatusMessage(
            icon: Icons.pin_drop_outlined,
            title: 'Lokasiya icazəsi lazımdır',
            subtitle: 'Ətrafındakı insanları görmək üçün icazə ver.',
            actionLabel: 'Yenidən cəhd et',
            onAction: () => ref.read(locationControllerProvider.notifier).refresh(),
          );
        case LocationFailure.permissionDeniedForever:
          return _StatusMessage(
            icon: Icons.settings_outlined,
            title: 'İcazə həmişəlik rədd edilib',
            subtitle: 'Telefonun ayarlarından "Kim Var" üçün lokasiya icazəsini əl ilə aç.',
            actionLabel: 'Tətbiq ayarlarını aç',
            onAction: () => Geolocator.openAppSettings(),
          );
      }
    }

    return _StatusMessage(
      icon: Icons.error_outline,
      title: 'Xəta baş verdi',
      subtitle: '$error',
      actionLabel: 'Yenidən cəhd et',
      onAction: () => ref.read(locationControllerProvider.notifier).refresh(),
    );
  }

  Widget _buildMap(Position position, List<NearbyUser> nearbyUsers) {
    final center = LatLng(position.latitude, position.longitude);
    final radiusKm = ref.watch(selectedRadiusKmProvider);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: center,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Sən buradasan'),
      ),
      for (final u in nearbyUsers)
        Marker(
          markerId: MarkerId(u.id),
          position: LatLng(u.lat, u.lng),
          onTap: () => _showUserCard(context, position, u),
        ),
    };

    // Fit the camera to the radius so the circle is fully visible
    // whenever the user changes it.
    final zoom = _zoomForRadiusKm(radiusKm);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: zoom),
          onMapCreated: (controller) => _mapController = controller,
          markers: markers,
          circles: {
            Circle(
              circleId: const CircleId('radius'),
              center: center,
              radius: radiusKm * 1000,
              fillColor: AppColors.primary.withOpacity(0.08),
              strokeColor: AppColors.primary.withOpacity(0.4),
              strokeWidth: 1,
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onCameraMove: (_) {},
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            onPressed: () {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(center, _zoomForRadiusKm(radiusKm)));
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  double _zoomForRadiusKm(double radiusKm) {
    if (radiusKm <= 1) return 15;
    if (radiusKm <= 5) return 13;
    if (radiusKm <= 10) return 12;
    if (radiusKm <= 25) return 10.5;
    return 9;
  }

  void _showRadiusSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Axtarış radiusu',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
                ...kRadiusOptionsKm.map((km) {
                  final selected = ref.watch(selectedRadiusKmProvider) == km;
                  return ListTile(
                    onTap: () {
                      ref.read(selectedRadiusKmProvider.notifier).state = km;
                      Navigator.pop(sheetContext);
                    },
                    title: Text(
                      _formatRadius(km),
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.white,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserCard(BuildContext context, Position myPosition, NearbyUser user) {
    final distanceMeters = user.distanceMeters;

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
                Row(
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
                          ? const Icon(Icons.person, color: AppColors.primary, size: 30)
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
                                  user.name,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.online) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            distanceMeters < 1000
                                ? '${distanceMeters.round()} m aralı'
                                : '${(distanceMeters / 1000).toStringAsFixed(1)} km aralı',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user.mainInterest.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      user.mainInterest,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF00281E)),
                        label: const Text('Söhbətə başla'),
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
}

String _formatRadius(double km) {
  return km >= 1 ? '${km.toStringAsFixed(0)} km' : '${(km * 1000).toStringAsFixed(0)} m';
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
                  BoxShadow(color: AppColors.glow, blurRadius: 40, spreadRadius: 4),
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
                  : Icon(icon, color: AppColors.primary, size: 42),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.white),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
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
