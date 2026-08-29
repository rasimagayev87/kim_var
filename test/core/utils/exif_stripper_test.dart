import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:peakpin/core/utils/exif_stripper.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('exif_stripper_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('strips GPS EXIF data from a JPEG', () async {
    final image = img.Image(width: 4, height: 4);
    image.exif.gpsIfd.setGpsLocation(latitude: 40.4093, longitude: 49.8671);
    expect(image.exif.gpsIfd.isEmpty, isFalse);
    expect(image.exif.gpsIfd.hasGPSLatitude, isTrue);

    final sourceBytes = img.encodeJpg(image);
    final sourceFile = File('${tempDir.path}/source_with_gps.jpg')
      ..writeAsBytesSync(sourceBytes);

    final stripped = await stripExifIfImage(sourceFile);
    final decoded = img.decodeJpg(stripped.readAsBytesSync());

    expect(decoded, isNotNull);
    expect(decoded!.exif.gpsIfd.isEmpty, isTrue);
  });

  test('fails open — returns the original file for non-image bytes', () async {
    final notAnImage = File('${tempDir.path}/not_an_image.jpg')
      ..writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

    final result = await stripExifIfImage(notAnImage);

    expect(result.path, notAnImage.path);
  });
}
