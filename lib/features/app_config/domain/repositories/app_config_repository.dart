import '../entities/app_config.dart';

abstract class AppConfigRepository {
  /// Sets Remote Config defaults + fetch settings, and — only on a
  /// genuinely first-ever launch (no previously-activated cache at all)
  /// — awaits one bounded fetch (≤3s) so the very first open can still
  /// see a maintenance/force-update signal. On every later launch this
  /// returns near-instantly, reading whatever was already cached from
  /// the last successful fetch, and kicks off a fresh fetch in the
  /// background rather than blocking on it.
  Future<void> init();

  /// The current config, read synchronously from whatever's cached/
  /// activated right now — never triggers a network call itself.
  /// [languageCode] (e.g. `'az'`, `'en'`) picks which per-locale
  /// suffix resolves the maintenance/read-only/announcement message.
  AppConfig current({required String languageCode});

  /// Re-fetches from the network and activates the result, updating
  /// what [current] returns afterward. Never throws — a failure just
  /// means [current] keeps returning what it already had.
  Future<void> refresh();
}
