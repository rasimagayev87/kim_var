import 'package:flutter/material.dart';

/// Transforms a Firebase Storage download URL into the URL the
/// `storage-resize-images` extension's derived thumbnail would live
/// at (`extensions/storage-resize-images.env`: `IMG_SIZES=200x200`,
/// `RESIZED_IMAGES_PATH` unset, so it sits next to the original as
/// `{name}_200x200.{ext}`). Pure string manipulation — no Storage
/// lookup — because `REGENERATE_TOKEN=false` in that same config
/// deliberately makes the resized object reuse the original's
/// download token, so the identical `?alt=media&token=...` query
/// string works for both; only the encoded object-path segment
/// changes. Never touches percent-decoding: since `.`/`_` aren't
/// characters Firebase's own URL builder escapes, the suffix can be
/// spliced directly into the still-encoded path.
///
/// Returns null when [url] doesn't look like a Firebase Storage
/// download URL, or already looks like a resized one — callers should
/// just use the original in either case.
String? deriveThumbnailUrl(String url) {
  const marker = '/o/';
  final markerIndex = url.indexOf(marker);
  if (markerIndex == -1) return null;

  final pathStart = markerIndex + marker.length;
  final queryIndex = url.indexOf('?', pathStart);
  final encodedPath = queryIndex == -1 ? url.substring(pathStart) : url.substring(pathStart, queryIndex);
  final query = queryIndex == -1 ? '' : url.substring(queryIndex);

  final dotIndex = encodedPath.lastIndexOf('.');
  if (dotIndex <= 0) return null;
  if (encodedPath.substring(0, dotIndex).endsWith('_200x200')) return null;

  final resizedPath = '${encodedPath.substring(0, dotIndex)}_200x200${encodedPath.substring(dotIndex)}';
  return '${url.substring(0, pathStart)}$resizedPath$query';
}

/// Drop-in replacement for `Image.network(url, ...)` wherever the
/// source is one of the Storage paths the Resize Images extension
/// covers (see `extensions/storage-resize-images.env`'s
/// `INCLUDE_PATH_LIST`) — same constructor shape, so swapping an
/// existing call site is a mechanical rename plus one new [thumbnail]
/// argument, nothing else about the call site needs to change.
///
/// [thumbnail] true (grid/list tiles — Kəşf, Canlı, Fürsətlər, post
/// grids) loads the small `_200x200` derivative for faster, cheaper
/// loads; false (full-screen/detail views — VenueProfileScreen,
/// OfferDetailsScreen, post detail/reel viewers) loads [url] as-is.
///
/// A thumbnail 404s the FIRST time an image is viewed shortly after
/// upload (the resize function hasn't finished yet) or for any path
/// [deriveThumbnailUrl] can't confidently transform (identity
/// verification images are excluded from the extension entirely and
/// would always fall back) — [errorBuilder] transparently retries
/// with the original full-size [url] instead of showing a broken-image
/// icon, so this is always at least as reliable as a plain
/// `Image.network(url)` was before, never less.
class AppImage extends StatelessWidget {
  final String url;
  final bool thumbnail;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppImage(
    this.url, {
    super.key,
    this.thumbnail = false,
    this.fit,
    this.width,
    this.height,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = thumbnail ? deriveThumbnailUrl(url) : null;

    return Image.network(
      thumbnailUrl ?? url,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: loadingBuilder,
      errorBuilder: thumbnailUrl == null
          ? errorBuilder
          : (context, error, stackTrace) => Image.network(
                url,
                fit: fit,
                width: width,
                height: height,
                loadingBuilder: loadingBuilder,
                errorBuilder: errorBuilder,
              ),
    );
  }
}
