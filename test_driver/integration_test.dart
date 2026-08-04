import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Writes each `binding.takeScreenshot(name)` call from
/// `integration_test/app_screenshots_test.dart` to `screenshots/NAME.png`
/// on the host machine — the on-device test already embeds the
/// android/ios subfolder in `name`, so this just needs to write the
/// bytes to that path verbatim.
Future<void> main() => integrationDriver(
      onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
        final file = File('screenshots/$screenshotName.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(screenshotBytes);
        return true;
      },
    );
