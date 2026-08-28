import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/app_config/domain/entities/app_config.dart';

/// A full Firebase-platform-channel-mocked test of
/// `RemoteConfigDataSource.init()` swallowing a genuine fetch failure
/// (the scenario HİSSƏ E calls out as the critical case) needs
/// `mocktail` (not yet a dev dependency) plus mocked
/// `firebase_core`/`firebase_remote_config` platform channels — real,
/// valuable follow-up work, flagged explicitly in this feature's
/// handoff report rather than attempted here without that
/// infrastructure in place.
///
/// What IS tested here, without any Firebase test harness: the
/// contract [RemoteConfigDataSource.init] depends on to make a failed
/// fetch harmless in the first place — that a bare, all-defaults
/// [AppConfig] (equivalent to what the app has before any fetch ever
/// completes, successful or not) is itself a fully valid, safe-to-boot
/// config on its own.
void main() {
  test('an all-defaults AppConfig never blocks the app from opening', () {
    const config = AppConfig();

    expect(config.forceUpdateEnabled, false);
    expect(config.maintenanceModeEnabled, false);
    expect(config.readOnlyModeEnabled, false);
    expect(config.radiusOptionsKm, isNotEmpty);
    expect(config.isFeatureEnabled(FeatureFlag.mediaUpload), true);
    // Every flag not explicitly listed still defaults to enabled — a
    // flag this build doesn't recognize should never hide a feature it
    // doesn't know about.
    expect(config.featureFlags.length, FeatureFlag.values.length);
  });

  test('isFeatureEnabled falls back to true for a flag with no explicit entry', () {
    const config = AppConfig(featureFlags: {});
    expect(config.isFeatureEnabled(FeatureFlag.calls), true);
  });

  test('business offer fields default to a bundled URL/version, never empty', () {
    const config = AppConfig();
    expect(config.urlBusinessOffer, isNotEmpty);
    expect(config.businessOfferVersion, isNotEmpty);
    expect(config.businessOfferEffectiveDate, isNotEmpty);
  });
}
