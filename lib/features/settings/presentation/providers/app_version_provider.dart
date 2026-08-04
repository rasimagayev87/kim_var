import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The app's real installed version (from the native build, itself
/// generated from `pubspec.yaml`'s `version:` field) — never hardcoded.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version}';
});
