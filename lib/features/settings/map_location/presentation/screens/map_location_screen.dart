import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/distance_unit.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/map_location_settings.dart';
import '../providers/map_location_providers.dart';

class MapLocationScreen extends ConsumerWidget {
  const MapLocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final settingsAsync = ref.watch(mapLocationSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const MapLocationSettings();
    final controller = ref.read(mapLocationSettingsControllerProvider);

    void showError() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.mapLocationUpdateErrorMessage)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.mapLocationScreenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.map_outlined,
                  title: loc.mapTypeTitle,
                  trailing: SettingsPill(label: _mapTypeLabel(loc, settings.mapType)),
                  onTap: () => _showOptionsSheet<AppMapType>(
                    context: context,
                    title: loc.mapTypeTitle,
                    current: settings.mapType,
                    options: [
                      _Option(AppMapType.standard, loc.mapTypeStandard),
                      _Option(AppMapType.satellite, loc.mapTypeSatellite),
                      _Option(AppMapType.hybrid, loc.mapTypeHybrid),
                    ],
                    onSelected: (v) async {
                      final ok = await controller.updateMapType(v);
                      if (!ok && context.mounted) showError();
                    },
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.straighten_outlined,
                  title: loc.distanceUnitTitle,
                  trailing: SettingsPill(label: _distanceUnitLabel(loc, settings.distanceUnit)),
                  onTap: () => _showOptionsSheet<DistanceUnit>(
                    context: context,
                    title: loc.distanceUnitTitle,
                    current: settings.distanceUnit,
                    options: [
                      _Option(DistanceUnit.km, loc.distanceUnitKm),
                      _Option(DistanceUnit.mi, loc.distanceUnitMi),
                    ],
                    onSelected: (v) async {
                      final ok = await controller.updateDistanceUnit(v);
                      if (!ok && context.mounted) showError();
                    },
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.location_searching_outlined,
                  title: loc.gpsAccuracyTitle,
                  trailing: SettingsPill(label: _gpsAccuracyLabel(loc, settings.gpsAccuracy)),
                  onTap: () => _showOptionsSheet<GpsAccuracyLevel>(
                    context: context,
                    title: loc.gpsAccuracyTitle,
                    current: settings.gpsAccuracy,
                    options: [
                      _Option(GpsAccuracyLevel.high, loc.gpsAccuracyHigh),
                      _Option(GpsAccuracyLevel.standard, loc.gpsAccuracyStandard),
                    ],
                    onSelected: (v) async {
                      final ok = await controller.updateGpsAccuracy(v);
                      if (!ok && context.mounted) showError();
                    },
                  ),
                ),
                SettingsToggleRow(
                  icon: Icons.my_location_outlined,
                  title: loc.backgroundLocationTitle,
                  subtitle: loc.backgroundLocationSubtitle,
                  value: settings.backgroundLocationEnabled,
                  onChanged: (v) async {
                    if (!v) {
                      final ok = await controller.disableBackgroundLocation();
                      if (!ok && context.mounted) showError();
                      return;
                    }
                    final result = await controller.enableBackgroundLocation();
                    if (!context.mounted) return;
                    switch (result) {
                      case BackgroundLocationResult.granted:
                        break;
                      case BackgroundLocationResult.deniedNeedsSettings:
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.backgroundLocationDeniedMessage)),
                        );
                      case BackgroundLocationResult.failed:
                        showError();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _mapTypeLabel(AppLocalizations loc, AppMapType type) {
    switch (type) {
      case AppMapType.standard:
        return loc.mapTypeStandard;
      case AppMapType.satellite:
        return loc.mapTypeSatellite;
      case AppMapType.hybrid:
        return loc.mapTypeHybrid;
    }
  }

  String _distanceUnitLabel(AppLocalizations loc, DistanceUnit unit) {
    return unit == DistanceUnit.km ? loc.distanceUnitKm : loc.distanceUnitMi;
  }

  String _gpsAccuracyLabel(AppLocalizations loc, GpsAccuracyLevel level) {
    return level == GpsAccuracyLevel.high ? loc.gpsAccuracyHigh : loc.gpsAccuracyStandard;
  }
}

class _Option<T> {
  final T value;
  final String label;

  const _Option(this.value, this.label);
}

void _showOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required T current,
  required List<_Option<T>> options,
  required void Function(T value) onSelected,
}) {
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
                  child: Text(title, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              for (final option in options)
                ListTile(
                  title: Text(option.label, style: AppTextStyles.body.copyWith(fontSize: 15.5)),
                  leading: Icon(
                    option.value == current ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: option.value == current ? AppColors.primary : AppColors.textMuted,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelected(option.value);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
