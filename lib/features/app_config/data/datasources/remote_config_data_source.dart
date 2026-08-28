import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/app_logger.dart';

/// Bundled defaults for every Remote Config key this app reads — see
/// `docs/BACKWARD_COMPATIBILITY.md` for the same list with types, kept
/// in sync manually (this file is the source of truth for what actually
/// ships in the app; the doc is the copy-pasteable list for Firebase
/// Console). Every value here matches whatever the app already did
/// before Remote Config existed, so a fresh install with zero network
/// behaves identically to before this feature shipped.
final Map<String, dynamic> _defaults = {
  'force_update_enabled': false,
  'min_supported_version_android': '1.0.0',
  'min_supported_version_ios': '1.0.0',
  'latest_version_android': '1.0.0',
  'latest_version_ios': '1.0.0',
  'update_store_url_android': 'https://play.google.com/store/apps/details?id=com.peakpin.app',
  'update_store_url_ios': 'https://apps.apple.com/app/id0000000000',
  'soft_update_interval_hours': 72,
  'maintenance_mode_enabled': false,
  'maintenance_message_az': '',
  'maintenance_message_en': '',
  'maintenance_message_tr': '',
  'maintenance_message_ru': '',
  'read_only_mode_enabled': false,
  'read_only_message_az': '',
  'read_only_message_en': '',
  'read_only_message_tr': '',
  'read_only_message_ru': '',
  'announcement_enabled': false,
  'announcement_id': '',
  'announcement_message_az': '',
  'announcement_message_en': '',
  'announcement_message_tr': '',
  'announcement_message_ru': '',
  'announcement_action_url': '',
  'feature_venue_submission_enabled': true,
  'feature_offers_enabled': true,
  'feature_indi_tab_enabled': true,
  'feature_calls_enabled': true,
  'feature_stories_enabled': true,
  'feature_vip_purchase_enabled': true,
  'feature_boost_payment_enabled': true,
  'feature_waitlist_enabled': true,
  'feature_news_agency_enabled': true,
  'feature_media_upload_enabled': true,
  'url_privacy_policy': 'https://peakpin.app/privacy-policy.html',
  'url_terms_of_service': 'https://peakpin.app/terms-of-service.html',
  'url_community_guidelines': 'https://peakpin.app/community-guidelines.html',
  'url_business_offer': 'https://peakpin.app/business-offer.html',
  'business_offer_version': '1.0',
  'business_offer_effective_date': '2026-08-28',
  'support_email': 'support@peakpin.app',
  'privacy_email': 'privacy@peakpin.app',
  'support_phone': '',
  'radius_options_json': '[0.1,0.5,1,5,10,30]',
  'vip_radius_threshold_m': 0,
  'social_instagram_url': '',
  'social_tiktok_url': '',
};

/// The only class in this codebase that touches `firebase_remote_config`
/// directly — everything else reads through [AppConfigRepository].
class RemoteConfigDataSource {
  RemoteConfigDataSource({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  /// See [AppConfigRepository.init]'s own doc comment for the cache-first,
  /// bounded-only-on-first-launch contract this implements.
  Future<void> init() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await _remoteConfig.setDefaults(_defaults);

      final isFirstEverFetch = _remoteConfig.lastFetchTime.millisecondsSinceEpoch == 0;
      if (isFirstEverFetch) {
        try {
          await _remoteConfig.fetchAndActivate().timeout(
            const Duration(seconds: 3),
            onTimeout: () => false,
          );
        } catch (e, st) {
          logError('app_config.RemoteConfigDataSource.init.firstFetch', e, st);
        }
      } else {
        unawaited(refresh());
      }
    } catch (e, st) {
      // setDefaults/setConfigSettings failing entirely (e.g. Remote
      // Config unreachable/misconfigured) must never block startup —
      // every getter below already falls back to the bundled Dart-level
      // default when the SDK itself has nothing to return.
      logError('app_config.RemoteConfigDataSource.init', e, st);
    }
  }

  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e, st) {
      logError('app_config.RemoteConfigDataSource.refresh', e, st);
    }
  }

  bool getBool(String key) => _remoteConfig.getBool(key);
  String getString(String key) => _remoteConfig.getString(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);
}
