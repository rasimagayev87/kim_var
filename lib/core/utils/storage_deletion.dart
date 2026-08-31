import 'package:firebase_storage/firebase_storage.dart';

/// The suffix the `storage-resize-images` extension appends. Kept in
/// step BY HAND with `IMG_SIZES` in
/// `extensions/storage-resize-images.env`, `deriveThumbnailUrl` in
/// `lib/core/widgets/app_image.dart`, and `RESIZED_IMAGE_SUFFIX` in
/// `functions/src/chat-media.ts` — four places that must agree.
const kResizedImageSuffix = '_200x200';

/// The object path of the `_200x200` copy sitting next to [path], or
/// null when [path] cannot have one.
///
/// Mirrors `resizedVariantPath` in `functions/src/chat-media.ts`. The
/// Dart and TypeScript sides cannot share code, so the shapes are kept
/// identical deliberately.
String? resizedVariantPath(String path) {
  if (path.isEmpty) return null;
  final slash = path.lastIndexOf('/');
  final dot = path.lastIndexOf('.');
  // No extension, or the dot belongs to a directory name rather than
  // the file ("a.b/c") — nothing to splice a suffix in front of.
  if (dot <= slash + 1) return null;
  final base = path.substring(0, dot);
  if (base.endsWith(kResizedImageSuffix)) return null; // already a derivative
  return '$base$kResizedImageSuffix${path.substring(dot)}';
}

/// Deletes [ref] AND the resized copy the extension made from it.
///
/// Every client-side delete used to name only the original. That was
/// invisible for a long time because `storage.rules` granted these
/// paths `allow write` with a size condition, and a delete carries no
/// `request.resource` — so the delete was denied and the callers, all
/// of which swallow errors as best-effort, never noticed. Once that
/// rule was split into `create, update` / `delete` the deletes started
/// working, and immediately left a trail of orphaned `_200x200` files
/// behind: a venue's photo was removed while its thumbnail stayed.
///
/// That is a leak, not just wasted bytes. `REGENERATE_TOKEN=false`
/// means the derivative carries the ORIGINAL's download token, so
/// anyone holding the original URL reaches the copy by editing one
/// path segment — after the user believes they deleted it.
///
/// The derivative is deleted FIRST and its failure ignored: paths the
/// extension does not cover (chat video and audio) simply have none,
/// and a missing object must not stop the original from going.
Future<void> deleteWithResizedVariant(Reference ref) async {
  final derivative = resizedVariantPath(ref.fullPath);
  if (derivative != null) {
    try {
      await ref.storage.ref(derivative).delete();
    } catch (_) {
      // Expected whenever there is no derivative (non-image paths, or
      // an upload the extension never processed).
    }
  }
  await ref.delete();
}
