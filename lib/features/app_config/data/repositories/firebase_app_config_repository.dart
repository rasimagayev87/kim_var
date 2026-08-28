import 'dart:convert';

import '../../../../core/utils/safe_parse.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/repositories/app_config_repository.dart';
import '../datasources/remote_config_data_source.dart';

class FirebaseAppConfigRepository implements AppConfigRepository {
  FirebaseAppConfigRepository({RemoteConfigDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteConfigDataSource();

  final RemoteConfigDataSource _dataSource;

  @override
  Future<void> init() => _dataSource.init();

  @override
  Future<void> refresh() => _dataSource.refresh();

  @override
  AppConfig current({required String languageCode}) {
    const fallbackLocale = 'en';
    String localized(String baseKey) {
      final value = _dataSource.getString('${baseKey}_$languageCode');
      if (value.isNotEmpty) return value;
      return _dataSource.getString('${baseKey}_$fallbackLocale');
    }

    return AppConfig(
      forceUpdateEnabled: _dataSource.getBool('force_update_enabled'),
      minSupportedVersionAndroid: _dataSource.getString('min_supported_version_android'),
      minSupportedVersionIos: _dataSource.getString('min_supported_version_ios'),
      latestVersionAndroid: _dataSource.getString('latest_version_android'),
      latestVersionIos: _dataSource.getString('latest_version_ios'),
      updateStoreUrlAndroid: _dataSource.getString('update_store_url_android'),
      updateStoreUrlIos: _dataSource.getString('update_store_url_ios'),
      softUpdateIntervalHours: _dataSource.getInt('soft_update_interval_hours'),
      maintenanceModeEnabled: _dataSource.getBool('maintenance_mode_enabled'),
      maintenanceMessage: localized('maintenance_message'),
      readOnlyModeEnabled: _dataSource.getBool('read_only_mode_enabled'),
      readOnlyMessage: localized('read_only_message'),
      announcementEnabled: _dataSource.getBool('announcement_enabled'),
      announcementId: _dataSource.getString('announcement_id'),
      announcementMessage: localized('announcement_message'),
      announcementActionUrl: _dataSource.getString('announcement_action_url'),
      featureFlags: {
        FeatureFlag.venueSubmission: _dataSource.getBool('feature_venue_submission_enabled'),
        FeatureFlag.offers: _dataSource.getBool('feature_offers_enabled'),
        FeatureFlag.indiTab: _dataSource.getBool('feature_indi_tab_enabled'),
        FeatureFlag.calls: _dataSource.getBool('feature_calls_enabled'),
        FeatureFlag.stories: _dataSource.getBool('feature_stories_enabled'),
        FeatureFlag.vipPurchase: _dataSource.getBool('feature_vip_purchase_enabled'),
        FeatureFlag.boostPayment: _dataSource.getBool('feature_boost_payment_enabled'),
        FeatureFlag.waitlist: _dataSource.getBool('feature_waitlist_enabled'),
        FeatureFlag.newsAgency: _dataSource.getBool('feature_news_agency_enabled'),
        FeatureFlag.mediaUpload: _dataSource.getBool('feature_media_upload_enabled'),
      },
      urlPrivacyPolicy: _dataSource.getString('url_privacy_policy'),
      urlTermsOfService: _dataSource.getString('url_terms_of_service'),
      urlCommunityGuidelines: _dataSource.getString('url_community_guidelines'),
      urlBusinessOffer: _dataSource.getString('url_business_offer'),
      businessOfferVersion: _dataSource.getString('business_offer_version'),
      businessOfferEffectiveDate: _dataSource.getString('business_offer_effective_date'),
      urlChildSafetyStandards: _dataSource.getString('url_child_safety_standards'),
      supportEmail: _dataSource.getString('support_email'),
      privacyEmail: _dataSource.getString('privacy_email'),
      supportPhone: _dataSource.getString('support_phone'),
      radiusOptionsKm: _parseRadiusOptions(_dataSource.getString('radius_options_json')),
      vipRadiusThresholdM: _dataSource.getDouble('vip_radius_threshold_m'),
      socialInstagramUrl: _dataSource.getString('social_instagram_url'),
      socialTiktokUrl: _dataSource.getString('social_tiktok_url'),
    );
  }

  /// Falls back to the same literal list `kRadiusOptionsKm` already had
  /// before this field became remote-configurable, if the JSON is
  /// missing/malformed — never lets a bad Console value empty the
  /// radius picker.
  List<double> _parseRadiusOptions(String json) {
    if (json.isEmpty) return const [0.1, 0.5, 1, 5, 10, 30];
    try {
      final decoded = jsonDecode(json);
      final parsed = safeList<double>(decoded, (e) => safeDouble(e));
      return parsed.isEmpty ? const [0.1, 0.5, 1, 5, 10, 30] : parsed;
    } catch (_) {
      return const [0.1, 0.5, 1, 5, 10, 30];
    }
  }
}
