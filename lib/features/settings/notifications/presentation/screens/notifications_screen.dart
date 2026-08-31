import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/notification_preferences.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final prefs = prefsAsync.valueOrNull ?? const NotificationPreferences();
    final controller = ref.read(notificationPreferencesControllerProvider);
    final permissionStatus = ref.watch(notificationPermissionStatusProvider).valueOrNull;
    final permissionDenied = permissionStatus == ph.PermissionStatus.denied ||
        permissionStatus == ph.PermissionStatus.permanentlyDenied;

    void showError() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.notifUpdateErrorMessage)),
      );
    }

    Future<void> onCategoryChanged(String key, bool value) async {
      final ok = await controller.toggleCategory(key, value, prefs.pushEnabled);
      if (!ok && context.mounted) showError();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.notificationsScreenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (permissionDenied) ...[
              _PermissionDeniedBanner(onOpenSettings: ph.openAppSettings),
              const SizedBox(height: 16),
            ],
            SettingsGroup(
              children: [
                SettingsToggleRow(
                  icon: Icons.chat_bubble_outline,
                  title: loc.notifMessagesTitle,
                  subtitle: loc.notifMessagesSubtitle,
                  value: prefs.messages,
                  onChanged: (v) => onCategoryChanged('messages', v),
                ),
                SettingsToggleRow(
                  icon: Icons.person_add_alt_outlined,
                  title: loc.notifFollowersTitle,
                  subtitle: loc.notifFollowersSubtitle,
                  value: prefs.followers,
                  onChanged: (v) => onCategoryChanged('followers', v),
                ),
                SettingsToggleRow(
                  icon: Icons.favorite_border,
                  title: loc.notifLikesTitle,
                  subtitle: loc.notifLikesSubtitle,
                  value: prefs.likes,
                  onChanged: (v) => onCategoryChanged('likes', v),
                ),
                SettingsToggleRow(
                  icon: Icons.mode_comment_outlined,
                  title: loc.notifCommentsTitle,
                  subtitle: loc.notifCommentsSubtitle,
                  value: prefs.comments,
                  onChanged: (v) => onCategoryChanged('comments', v),
                ),
                SettingsToggleRow(
                  icon: Icons.local_offer_outlined,
                  title: loc.notifVenueOffersTitle,
                  subtitle: loc.notifVenueOffersSubtitle,
                  value: prefs.venueOffers,
                  onChanged: (v) => onCategoryChanged('venueOffers', v),
                ),
                SettingsToggleRow(
                  icon: Icons.storefront_outlined,
                  title: loc.notifVenueUpdatesTitle,
                  subtitle: loc.notifVenueUpdatesSubtitle,
                  value: prefs.venueUpdates,
                  onChanged: (v) => onCategoryChanged('venueUpdates', v),
                ),
                // Both switches below already existed as stored fields
                // and as server-side gates on the admin panel's
                // broadcasts — with no UI. The user could not reach
                // them, so "PeakPin-dən elanlar" and promotional
                // messages were effectively unrefusable.
                SettingsToggleRow(
                  icon: Icons.campaign_outlined,
                  title: loc.notifSystemTitle,
                  subtitle: loc.notifSystemSubtitle,
                  value: prefs.systemNotifications,
                  onChanged: (v) => onCategoryChanged('systemNotifications', v),
                ),
                SettingsToggleRow(
                  icon: Icons.sell_outlined,
                  title: loc.notifMarketingTitle,
                  subtitle: loc.notifMarketingSubtitle,
                  value: prefs.marketing,
                  onChanged: (v) => onCategoryChanged('marketing', v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              children: [
                SettingsToggleRow(
                  icon: Icons.notifications_active_outlined,
                  title: loc.notifPushTitle,
                  value: prefs.pushEnabled,
                  onChanged: (v) async {
                    final ok = await controller.togglePush(v, prefs);
                    if (!ok && context.mounted) showError();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only when the OS-level permission is actually denied — every
/// toggle above this still reads/writes fine either way (this app's
/// own stored preference, not the OS permission), so without this
/// banner a user who denied the system prompt once has no way to
/// learn that's why nothing ever arrives.
class _PermissionDeniedBanner extends StatelessWidget {
  final Future<bool> Function() onOpenSettings;

  const _PermissionDeniedBanner({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_off_outlined, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.notifPermissionDeniedTitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.notifPermissionDeniedMessage,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onOpenSettings,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: AppColors.error.withValues(alpha: 0.15),
                    foregroundColor: AppColors.error,
                  ),
                  child: Text(loc.notifOpenSettingsButton, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
