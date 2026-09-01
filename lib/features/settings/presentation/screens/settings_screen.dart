import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_config/domain/entities/app_config.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/language_picker_sheet.dart';
import '../../../../core/localization/locale_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../identity_verification/presentation/screens/identity_verification_screen.dart';
import '../../../legal/presentation/screens/legal_hub_screen.dart';
import '../../../location/presentation/providers/presence_provider.dart';
import '../../../onboarding/presentation/screens/welcome_screen.dart';
import '../../../premium/presentation/providers/premium_providers.dart';
import '../../../premium/presentation/screens/vip_screen.dart';
import '../../../privacy/presentation/screens/privacy_security_screen.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/screens/change_photo_screen.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../../about/presentation/screens/about_screen.dart';
import '../../account/presentation/screens/account_screen.dart';
import '../../help/presentation/screens/help_screen.dart';
import '../../map_location/presentation/screens/map_location_screen.dart';
import '../../notifications/presentation/providers/notification_providers.dart';
import '../../notifications/presentation/screens/notifications_screen.dart';
import '../../payments/presentation/screens/payments_screen.dart';
import '../providers/app_version_provider.dart';

import '../../../../core/widgets/pressable.dart';

import '../../../../core/utils/app_logger.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              loc.settingsTitle,
              style: AppTextStyles.pageTitle.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 20),
            const _ProfileSummaryCard(),
            const SizedBox(height: 20),
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.person_outline,
                  title: loc.settingsAccountRowTitle,
                  subtitle: loc.settingsAccountRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountScreen()),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.photo_camera_outlined,
                  title: loc.changePhotoScreenTitle,
                  subtitle: loc.settingsChangePhotoRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePhotoScreen(),
                    ),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.shield_outlined,
                  title: loc.menuPrivacySecurity,
                  subtitle: loc.settingsPrivacyRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacySecurityScreen(),
                    ),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.notifications_outlined,
                  title: loc.menuNotifications,
                  subtitle: loc.settingsNotificationsRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
                _LanguageMenuRow(),
                _IdentityVerificationMenuRow(),
              ],
            ),
            const SizedBox(height: 12),
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.workspace_premium_outlined,
                  iconColor: AppColors.gold,
                  title: loc.settingsVipRowTitle,
                  subtitle: loc.settingsVipRowSubtitle,
                  trailing: isPremium
                      ? SettingsPill(label: loc.settingsVipActiveLabel)
                      : null,
                  // Existing subscribers can always reach this screen to
                  // manage what they already have — only *starting a new*
                  // purchase is what `FeatureFlag.vipPurchase` gates.
                  onTap:
                      !isPremium &&
                          !ref.watch(
                            featureFlagProvider(FeatureFlag.vipPurchase),
                          )
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VipScreen()),
                        ),
                ),
                SettingsMenuRow(
                  icon: Icons.map_outlined,
                  title: loc.settingsMapRowTitle,
                  subtitle: loc.settingsMapRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MapLocationScreen(),
                    ),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.credit_card_outlined,
                  title: loc.settingsPaymentsRowTitle,
                  subtitle: loc.settingsPaymentsRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.help_outline,
                  title: loc.settingsHelpRowTitle,
                  subtitle: loc.settingsHelpRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.description_outlined,
                  title: loc.settingsLegalRowTitle,
                  subtitle: loc.settingsLegalRowSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalHubScreen()),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.info_outline,
                  title: loc.settingsAboutRowTitle,
                  subtitle: loc.settingsAboutRowSubtitle,
                  trailing: SettingsPill(label: versionAsync.valueOrNull ?? ''),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SettingsGroup(children: [_LogoutRow()]),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends ConsumerWidget {
  const _ProfileSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = ref.watch(profileControllerProvider);
    final isPremium = ref.watch(isPremiumProvider);

    final displayName = profile.name.isEmpty
        ? loc.profileNamePlaceholder
        : profile.name;
    final handle = profile.username != null ? '@${profile.username}' : '';
    final locationText = _formatLocation(profile.city, profile.country);

    return Pressable(
      onTap: () => Navigator.pop(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: CustomPaint(
                size: const Size(160, 110),
                painter: _WavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.card,
                        backgroundImage: profile.photoUrl != null
                            ? NetworkImage(profile.photoUrl!)
                            : null,
                        child: profile.photoUrl == null
                            ? const Icon(
                                Icons.person_outline,
                                color: AppColors.textSecondary,
                                size: 30,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Pressable(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.background,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.onAccent,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: AppTextStyles.cardTitle.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPremium) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '👑',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      loc.settingsVipBadgeLabel,
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (handle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            handle,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (locationText != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                locationText,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_outlined,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatLocation(String? city, String? country) {
    final hasCity = city != null && city.isNotEmpty;
    final hasCountry = country != null && country.isNotEmpty;
    if (hasCity && hasCountry) return '$city, $country';
    if (hasCity) return city;
    if (hasCountry) return country;
    return null;
  }
}

/// Faint curved lines in the card's bottom-right corner — the "incə
/// dalğa/naxış effekti" from the reference, kept subtle (10% alpha) so
/// it reads as texture, not a competing graphic.
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var i = 0; i < 3; i++) {
      final yOffset = i * 16.0;
      final path = Path()
        ..moveTo(0, size.height * 0.55 + yOffset)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * 0.2 + yOffset,
          size.width,
          size.height * 0.55 + yOffset,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IdentityVerificationMenuRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);

    return SettingsMenuRow(
      icon: Icons.verified_user_outlined,
      title: loc.settingsIdentityVerificationRowTitle,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
      ),
    );
  }
}

class _LanguageMenuRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final currentLanguage = kSupportedLanguages.firstWhere(
      (language) => language.locale.languageCode == locale.languageCode,
      orElse: () => kSupportedLanguages.first,
    );

    return SettingsMenuRow(
      icon: Icons.language_outlined,
      title: loc.settingsLanguageRowLabel,
      subtitle: loc.settingsLanguageRowSubtitle,
      trailing: SettingsPill(label: currentLanguage.nativeName),
      onTap: () => showLanguagePickerSheet(context, ref),
    );
  }
}

/// How long to wait for the best-effort "mark offline" presence write
/// before giving up on it — mirrors `profile_tab.dart`'s
/// `_LogoutMenuItem`; sign-out must never hang on a flaky connection.
const _presenceWriteTimeout = Duration(seconds: 4);

class _LogoutRow extends ConsumerStatefulWidget {
  const _LogoutRow();

  @override
  ConsumerState<_LogoutRow> createState() => _LogoutRowState();
}

/// Ceiling for the fire-and-forget cleanup writes during logout. They
/// no longer block anything, but an unbounded pending future would keep
/// the old session's Firestore work alive after sign-out.
const _logoutCleanupTimeout = Duration(seconds: 5);

class _LogoutRowState extends ConsumerState<_LogoutRow> {
  bool _loggingOut = false;

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    // ORDER MATTERS, and it used to be wrong.
    //
    // Previously all three of `setOfflineNow`, `unregisterFcmToken` and
    // `signOut` were awaited in sequence and only then did the app
    // navigate — so tapping "log out" left the user staring at the
    // settings screen for several seconds while network writes
    // finished. `unregisterFcmToken` had no timeout at all.
    //
    // `signOut` IS awaited: it is the operation the user actually asked
    // for, it is fast (local credential clearing), and leaving it in the
    // background would drop the user on the welcome screen while still
    // authenticated — a worse bug than the delay.
    //
    // The two housekeeping writes are fire-and-forget WITH timeouts.
    // Neither changes what the user sees, and neither is worth a second
    // of their time: a presence flag goes stale on its own, and a stale
    // FCM token is pruned server-side by
    // `pruneStaleTokensAndLogFailures` on the next failed send.
    unawaited(
      ref
          .read(presenceControllerProvider)
          .setOfflineNow()
          .timeout(_presenceWriteTimeout, onTimeout: () {})
          .catchError((Object e, StackTrace st) {
            logError('settings_screen.logout.setOffline', e, st);
          }),
    );
    unawaited(
      ref
          .read(notificationPreferencesControllerProvider)
          .unregisterFcmToken()
          .timeout(_logoutCleanupTimeout, onTimeout: () {})
          .catchError((Object e, StackTrace st) {
            logError('settings_screen.logout.unregisterToken', e, st);
          }),
    );

    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorWithDetails(e.toString()))),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return InkWell(
      onTap: _loggingOut ? null : _handleLogout,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: _loggingOut
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.error,
                      ),
                    )
                  : const Icon(
                      Icons.logout_outlined,
                      color: AppColors.error,
                      size: 18,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.settingsLogoutRowTitle,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.settingsLogoutRowSubtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
