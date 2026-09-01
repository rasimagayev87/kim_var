import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/app_config.dart';
import '../providers/app_config_providers.dart';

const _kLastShownVersionKey = 'soft_update_last_shown_version';
const _kLastShownAtKey = 'soft_update_last_shown_at_ms';

/// Shows [SoftUpdateDialog] once, if all of these hold: an update is
/// actually available, the dialog hasn't already been shown for THIS
/// [latestVersion] within the last `soft_update_interval_hours` (a new
/// [latestVersion] resets the cooldown — see the version check below),
/// and the dialog isn't already showing. Call from the home shell once
/// past the splash gate; safe to call repeatedly (e.g. on every resume),
/// since the interval/version check makes repeat calls no-ops.
Future<void> maybeShowSoftUpdateDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final status = ref.read(updateStatusProvider);
  if (status != UpdateStatus.softUpdateAvailable) return;

  final config = ref.read(appConfigProvider);
  final latestVersion = Platform.isIOS
      ? config.latestVersionIos
      : config.latestVersionAndroid;

  final prefs = await SharedPreferences.getInstance();
  final lastShownVersion = prefs.getString(_kLastShownVersionKey);
  final lastShownAtMs = prefs.getInt(_kLastShownAtKey);

  final intervalElapsed =
      lastShownAtMs == null ||
      DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(lastShownAtMs),
          ) >=
          Duration(hours: config.softUpdateIntervalHours);

  // A newer `latest_version_*` always resets the cooldown, even if the
  // interval hasn't elapsed yet — a fresh release is worth re-prompting for.
  final shouldShow = lastShownVersion != latestVersion || intervalElapsed;
  if (!shouldShow || !context.mounted) return;

  await prefs.setString(_kLastShownVersionKey, latestVersion);
  await prefs.setInt(_kLastShownAtKey, DateTime.now().millisecondsSinceEpoch);

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => const SoftUpdateDialog(),
  );
}

class SoftUpdateDialog extends ConsumerWidget {
  const SoftUpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final storeUrl = Platform.isIOS
        ? config.updateStoreUrlIos
        : config.updateStoreUrlAndroid;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(loc.softUpdateTitle),
      content: Text(loc.softUpdateMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.softUpdateLaterButton),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            launchUrl(
              Uri.parse(storeUrl),
              mode: LaunchMode.externalApplication,
            );
            Navigator.pop(context);
          },
          child: Text(loc.softUpdateNowButton),
        ),
      ],
    );
  }
}
