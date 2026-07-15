import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../location/domain/location_failure.dart';
import '../../../location/domain/nearby_user.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../widgets/nearby_user_card_stack.dart';

enum _DiscoverView { map, cards }

class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  GoogleMapController? _mapController;
  _DiscoverView _view = _DiscoverView.map;

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationControllerProvider);
    final nearbyUsers = ref.watch(nearbyUsersProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Kəşf et',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ViewSwitcher(
              view: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
          if (_view == _DiscoverView.map) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _RadiusBadge(radiusKm: ref.watch(selectedRadiusKmProvider)),
                  const SizedBox(width: 10),
                  Expanded(child: _GenderFilterChips()),
                ],
              ),
            ),
          ],
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
              data: (position) => _view == _DiscoverView.map
                  ? _buildMap(position, nearbyUsers)
                  : NearbyUserCardStack(users: nearbyUsers),
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

    final zoom = _zoomForRadiusKm(radiusKm);

    return Column(
      children: [
        Expanded(
          child: Stack(
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
          ),
        ),
        _RadiusButtonRow(
          onSelected: (km) {
            ref.read(selectedRadiusKmProvider.notifier).state = km;
            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(center, _zoomForRadiusKm(km)));
          },
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

class _ViewSwitcher extends StatelessWidget {
  final _DiscoverView view;
  final ValueChanged<_DiscoverView> onChanged;

  const _ViewSwitcher({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _SwitcherOption(
            label: 'Xəritə',
            icon: Icons.map_outlined,
            selected: view == _DiscoverView.map,
            onTap: () => onChanged(_DiscoverView.map),
          ),
          _SwitcherOption(
            label: 'Kartlar',
            icon: Icons.style_outlined,
            selected: view == _DiscoverView.cards,
            onTap: () => onChanged(_DiscoverView.cards),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? const Color(0xFF00281E) : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF00281E) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadiusBadge extends StatelessWidget {
  final double radiusKm;

  const _RadiusBadge({required this.radiusKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            _formatRadius(radiusKm),
            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GenderFilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGenderFilterProvider);

    return Row(
      children: [
        _GenderChip(
          label: 'Hamı',
          selected: selected == GenderFilter.all,
          onTap: () => ref.read(selectedGenderFilterProvider.notifier).state = GenderFilter.all,
        ),
        const SizedBox(width: 6),
        _GenderChip(
          label: 'Kişi',
          selected: selected == GenderFilter.male,
          onTap: () => ref.read(selectedGenderFilterProvider.notifier).state = GenderFilter.male,
        ),
        const SizedBox(width: 6),
        _GenderChip(
          label: 'Qadın',
          selected: selected == GenderFilter.female,
          onTap: () => ref.read(selectedGenderFilterProvider.notifier).state = GenderFilter.female,
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF00281E) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RadiusButtonRow extends ConsumerWidget {
  final ValueChanged<double> onSelected;

  const _RadiusButtonRow({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKm = ref.watch(selectedRadiusKmProvider);

    return Container(
      color: AppColors.backgroundDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: kRadiusOptionsKm.map((km) {
          final selected = selectedKm == km;
          return GestureDetector(
            onTap: () => onSelected(km),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
              ),
              child: Text(
                _formatRadius(km),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF00281E) : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
