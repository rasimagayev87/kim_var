import 'package:flutter/material.dart';

import '../../../../core/navigation/deep_link_handler.dart' show navigatorKey;
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/app_config.dart';

/// Call at the top of any Controller method that writes to Firestore,
/// passing whatever the caller already has — `ref.read(appConfigProvider)`
/// works identically whether `ref` is a plain `Ref` (inside a Controller,
/// e.g. `PostController`, which only ever holds one) or a `WidgetRef`
/// (from a screen); this function itself only needs the resolved
/// [AppConfig], not the ref, so it works uniformly from both. Returns
/// `false` (and shows a `SnackBar` via the app's global [navigatorKey],
/// no `BuildContext` needed at the call site) when `read_only_mode_enabled`
/// is on — callers bail out immediately without attempting the write:
///
/// ```dart
/// Future<bool> submitReview(...) async {
///   if (!ensureWritableOrWarn(_ref.read(appConfigProvider))) return false;
///   ... existing write logic unchanged ...
/// }
/// ```
///
/// Reads still work as normal — this only gates the specific methods
/// it's added to, matching how each controller method already does its
/// own try/catch-and-report (see `PostController`, one extra line, not
/// a new pattern).
bool ensureWritableOrWarn(AppConfig config) {
  if (!config.readOnlyModeEnabled) return true;

  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return false;

  final loc = AppLocalizations.of(context);
  final message = config.readOnlyMessage.isNotEmpty
      ? config.readOnlyMessage
      : loc.readOnlyModeDefaultMessage;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  return false;
}
