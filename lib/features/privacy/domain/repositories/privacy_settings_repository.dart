import '../entities/privacy_settings.dart';

abstract class PrivacySettingsRepository {
  Stream<PrivacySettings> watchSettings(String uid);

  /// Single generic partial-update method (rather than one repository
  /// method per field) so adding a 13th settings section later never
  /// means touching this interface — only a new usecase that calls this
  /// with its own patch shape. Each usecase owns validating/shaping the
  /// patch it passes in.
  Future<void> updateSettings(String uid, Map<String, dynamic> patch);
}
