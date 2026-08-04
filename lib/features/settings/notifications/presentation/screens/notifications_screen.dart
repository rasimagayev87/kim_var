import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  icon: Icons.person_add_alt_1_outlined,
                  title: loc.notifNewUsersTitle,
                  subtitle: loc.notifNewUsersSubtitle,
                  value: prefs.newUsers,
                  onChanged: (v) => onCategoryChanged('newUsers', v),
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
                SettingsToggleRow(
                  icon: Icons.shield_outlined,
                  title: loc.notifSecurityTitle,
                  subtitle: loc.notifSecuritySubtitle,
                  value: prefs.security,
                  onChanged: (v) => onCategoryChanged('security', v),
                ),
                SettingsToggleRow(
                  icon: Icons.campaign_outlined,
                  title: loc.notifSystemTitle,
                  subtitle: loc.notifSystemSubtitle,
                  value: prefs.systemNotifications,
                  onChanged: (v) => onCategoryChanged('systemNotifications', v),
                ),
                SettingsToggleRow(
                  icon: Icons.local_activity_outlined,
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
                SettingsToggleRow(
                  icon: Icons.email_outlined,
                  title: loc.notifEmailTitle,
                  value: prefs.emailEnabled,
                  onChanged: (v) async {
                    final ok = await controller.toggleEmail(v);
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
