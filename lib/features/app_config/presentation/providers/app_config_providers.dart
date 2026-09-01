import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_providers.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/repositories/app_config_repository.dart';
import '../../domain/usecases/check_update_status_usecase.dart';

import '../../../../core/utils/app_logger.dart';

/// Overridden in `main()` with an already-`init()`-ed instance — see
/// that override's own comment for why (mirrors `localeProvider`'s
/// existing `overrideWith` pattern for the same "resolve before
/// runApp" reason).
final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => throw UnimplementedError(
    'appConfigRepositoryProvider must be overridden in main()',
  ),
);

/// Overridden in `main()` with the real installed version string (no
/// `v` prefix) — read once via `package_info_plus` before `runApp`,
/// same reasoning as [appConfigRepositoryProvider].
final installedAppVersionProvider = Provider<String>(
  (ref) => throw UnimplementedError(
    'installedAppVersionProvider must be overridden in main()',
  ),
);

class AppConfigController extends StateNotifier<AppConfig> {
  AppConfigController(this._repository, String languageCode)
    : super(_repository.current(languageCode: languageCode));

  final AppConfigRepository _repository;

  /// Re-resolves [state] from whatever's currently cached — call after
  /// [refresh] and whenever the app's locale changes, so already-fetched
  /// values re-localize without a new network round-trip.
  void reload(String languageCode) {
    state = _repository.current(languageCode: languageCode);
  }

  /// Triggers a real network fetch, then reloads [state] from the
  /// result. Never throws — see [AppConfigRepository.refresh].
  Future<void> refresh(String languageCode) async {
    await _repository.refresh();
    reload(languageCode);
  }
}

final appConfigProvider = StateNotifierProvider<AppConfigController, AppConfig>(
  (ref) {
    final languageCode = ref.watch(localeProvider).languageCode;
    final repository = ref.watch(appConfigRepositoryProvider);
    final controller = AppConfigController(repository, languageCode);

    // The Remote Config network fetch happens HERE, after the first
    // frame, rather than inside `main()` before `runApp()`.
    //
    // `RemoteConfigDataSource.init` now only registers the bundled
    // defaults (local, instant); waiting for the fetch was costing
    // seconds of blank screen on a cold start. Every value has a safe
    // bundled default, so the app is fully usable before this lands —
    // and because `AppConfigController` is a `StateNotifier`, whatever
    // the fetch changes rebuilds the widgets watching it. Without this
    // line the app would simply never see remote values.
    unawaited(
      controller.refresh(languageCode).catchError((Object e, StackTrace st) {
        logError('app_config.backgroundRefresh', e, st);
      }),
    );
    // Re-localize (no network) whenever the user switches app language.
    ref.listen(localeProvider, (previous, next) {
      if (previous?.languageCode != next.languageCode)
        controller.reload(next.languageCode);
    });
    return controller;
  },
);

final updateStatusProvider = Provider<UpdateStatus>((ref) {
  final config = ref.watch(appConfigProvider);
  final installedVersion = ref.watch(installedAppVersionProvider);
  return CheckUpdateStatusUseCase()(
    config: config,
    installedVersion: installedVersion,
  );
});

/// Typed per-feature gate — `ref.watch(featureFlagProvider(FeatureFlag.calls))`
/// instead of a scattered string lookup. Unknown/missing keys default to
/// enabled (see `AppConfig.isFeatureEnabled`), so a flag this build
/// doesn't recognize never hides a feature it doesn't know about.
final featureFlagProvider = Provider.family<bool, FeatureFlag>((ref, flag) {
  return ref.watch(appConfigProvider).isFeatureEnabled(flag);
});
