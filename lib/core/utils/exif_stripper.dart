import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

/// Strips EXIF metadata (GPS coordinates in particular — see C#43)
/// from a picked image before it's uploaded. `image_picker`'s own
/// `maxWidth`/`imageQuality` re-encode does NOT reliably do this — the
/// project's own security audit documents `image_picker_android`
/// putting GPS tags back even after that re-encode.
///
/// Decodes then re-encodes as JPEG, with the decoded [img.Image]'s EXIF
/// explicitly cleared before encoding — `decodeJpg` populates `.exif`
/// from the source file, and (confirmed by this file's own unit test,
/// not just assumed) `encodeJpg` writes whatever `.exif` currently
/// holds straight back out, so a plain decode→encode round trip alone
/// does NOT drop it; the explicit `image.exif = img.ExifData()` below
/// is what actually does. Fails open — if [file] isn't decodable as an
/// image for any reason, the ORIGINAL file is returned unchanged rather
/// than throwing, so a stripping bug never blocks an upload outright
/// (the existing `contentType.matches('image/.*')` Storage Rule and,
/// longer-term, a magic-byte trigger are what actually gate valid image
/// content — this function's job is metadata hygiene, not validation).
Future<File> stripExifIfImage(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return file;
    decoded.exif = img.ExifData();

    final stripped = img.encodeJpg(decoded, quality: 90);
    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/exif_stripped_${DateTime.now().microsecondsSinceEpoch}.jpg';
    return File(outPath)..writeAsBytesSync(stripped);
  } catch (e, st) {
    logError('exif_stripper.stripExifIfImage', e, st);
    return file;
  }
}
