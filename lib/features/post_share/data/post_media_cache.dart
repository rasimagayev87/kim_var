import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Disk-backed cache for post photo/video files, keyed by URL — the
/// single download/caching implementation every post-media flow
/// shares (media viewer background pre-cache, "Xarici tətbiqlə
/// paylaş", "Videonu endir"), so there's exactly one place that knows
/// how to turn a `mediaUrl` into a local [File].
///
/// Neither `Image.network` nor [VideoPlayerController.networkUrl]
/// (used to actually render posts) write anything to disk — Flutter's
/// built-in network image cache is in-memory only, and video playback
/// streams without ever producing a standalone file. A native share
/// sheet (especially AirDrop, or Mail's attachment picker) needs a
/// real local file path, not a remote URL, which is why this exists.
///
/// Files live under [getTemporaryDirectory] and are never explicitly
/// deleted by this class — they're subject to the OS's own temp-dir
/// eviction policy, same as any other cache. Downloads for the same
/// URL are de-duplicated via [_inFlight] so a background pre-cache
/// racing a user-initiated share/download doesn't fetch the same file
/// twice.
class PostMediaCache {
  PostMediaCache._();

  static final Map<String, Future<File>> _inFlight = {};

  /// Returns the cached file for [url] if it's already been fully
  /// downloaded, without starting a new download. Null if not cached
  /// (or still in the middle of downloading) — callers that want to
  /// wait for it should use [getOrDownload] instead.
  static Future<File?> getIfCached(String url) async {
    final file = await _fileFor(url);
    return await file.exists() ? file : null;
  }

  /// Returns the cached file for [url], downloading it first if
  /// needed. Safe to call repeatedly/concurrently for the same URL —
  /// only one real download ever happens at a time per URL.
  static Future<File> getOrDownload(
    String url, {
    required String extension,
    void Function(double progress)? onProgress,
  }) {
    return _inFlight.putIfAbsent(url, () => _download(url, extension, onProgress));
  }

  static Future<File> _download(String url, String extension, void Function(double progress)? onProgress) async {
    final file = await _fileFor(url, extension: extension);
    if (await file.exists()) return file;

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    final total = response.contentLength ?? 0;
    final sink = file.openWrite();

    var received = 0;
    await response.stream
        .map((chunk) {
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
          return chunk;
        })
        .pipe(sink);
    await sink.close();
    return file;
  }

  static Future<File> _fileFor(String url, {String extension = 'jpg'}) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/post_media_cache_${_stableHash(url)}.$extension');
  }

  /// A plain [String.hashCode] isn't guaranteed stable across app runs
  /// (Dart's docs explicitly don't promise that), which would silently
  /// break disk-cache lookups after a restart — this djb2 variant is a
  /// small, dependency-free hash that IS deterministic for the same
  /// input every time.
  static String _stableHash(String input) {
    var hash = 5381;
    for (final unit in input.codeUnits) {
      hash = ((hash << 5) + hash + unit) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
