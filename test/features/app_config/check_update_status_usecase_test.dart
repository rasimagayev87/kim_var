import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/app_config/domain/entities/app_config.dart';
import 'package:peakpin/features/app_config/domain/usecases/check_update_status_usecase.dart';

/// [AppConfig]'s Android/iOS fields are set to identical values
/// throughout — the usecase branches on `Platform.isIOS` internally,
/// and `flutter test` runs on neither a real iOS nor a real Android
/// device, so mirroring both fields is what makes these assertions
/// deterministic regardless of the host running the test.
AppConfig _config({
  bool forceUpdateEnabled = false,
  String minSupported = '1.0.0',
  String latest = '1.0.0',
}) {
  return AppConfig(
    forceUpdateEnabled: forceUpdateEnabled,
    minSupportedVersionAndroid: minSupported,
    minSupportedVersionIos: minSupported,
    latestVersionAndroid: latest,
    latestVersionIos: latest,
  );
}

void main() {
  final usecase = CheckUpdateStatusUseCase();

  test('up to date when installed version matches latest', () {
    final status = usecase(
      config: _config(latest: '1.2.0'),
      installedVersion: '1.2.0',
    );
    expect(status, UpdateStatus.upToDate);
  });

  test('soft update available when behind latest but force-update is off', () {
    final status = usecase(
      config: _config(latest: '1.3.0'),
      installedVersion: '1.2.0',
    );
    expect(status, UpdateStatus.softUpdateAvailable);
  });

  test('force update required when below min-supported AND force-update is on', () {
    final status = usecase(
      config: _config(forceUpdateEnabled: true, minSupported: '1.2.0', latest: '1.3.0'),
      installedVersion: '1.0.0',
    );
    expect(status, UpdateStatus.forceUpdateRequired);
  });

  test('force-update flag alone does not force an update for a version that meets the minimum', () {
    final status = usecase(
      config: _config(forceUpdateEnabled: true, minSupported: '1.0.0', latest: '1.3.0'),
      installedVersion: '1.2.0',
    );
    expect(status, UpdateStatus.softUpdateAvailable);
  });

  test('malformed installed version fails safe rather than throwing', () {
    expect(
      () => usecase(config: _config(latest: '1.2.0'), installedVersion: 'not-a-version'),
      returnsNormally,
    );
  });
}
