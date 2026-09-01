import 'dart:io';

import '../../../../core/utils/version_compare.dart';
import '../entities/app_config.dart';

/// Compares the installed app version against [AppConfig]'s
/// min-supported/latest values for the current platform and returns
/// which of the three update states applies. Never throws — a
/// malformed installed-version or config string just resolves to
/// [UpdateStatus.upToDate] via [compareVersions]'s own fail-safe
/// contract, since gating an update on unreliable input would be worse
/// than not gating it at all.
class CheckUpdateStatusUseCase {
  UpdateStatus call({
    required AppConfig config,
    required String installedVersion,
  }) {
    final minSupported = Platform.isIOS
        ? config.minSupportedVersionIos
        : config.minSupportedVersionAndroid;
    final latest = Platform.isIOS
        ? config.latestVersionIos
        : config.latestVersionAndroid;

    if (config.forceUpdateEnabled &&
        compareVersions(installedVersion, minSupported) < 0) {
      return UpdateStatus.forceUpdateRequired;
    }
    if (compareVersions(installedVersion, latest) < 0) {
      return UpdateStatus.softUpdateAvailable;
    }
    return UpdateStatus.upToDate;
  }
}
