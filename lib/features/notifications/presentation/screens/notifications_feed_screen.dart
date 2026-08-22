import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../settings/notifications/presentation/screens/notifications_screen.dart' as settings;
import '../../domain/entities/notification.dart';
import '../notification_localizer.dart';
import '../notification_navigation.dart';
import '../providers/notification_providers.dart';

enum _NotificationMenuAction { markAllRead, deleteRead, openSettings }

/// The "Bildirişlər" bottom-nav tab — replaces the removed Tədbirlər
/// tab. Reuses the exact light design system already established for
/// Söhbət/Kəşf et → Məkanlar (soft-gray gradient + contour background,
/// cyan accent, rounded-22 white cards) rather than introducing a new
/// palette, per the design-system requirement.
class NotificationsFeedScreen extends ConsumerStatefulWidget {
  const NotificationsFeedScreen({super.key});

  @override
  ConsumerState<NotificationsFeedScreen> createState() => _NotificationsFeedScreenState();
}

class _NotificationsFeedScreenState extends ConsumerState<NotificationsFeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(notificationListControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openMenu() async {
    final loc = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_NotificationMenuAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.done_all_rounded, color: ChatLightColors.ink),
              title: Text(loc.notifMenuMarkAllRead, style: const TextStyle(color: ChatLightColors.ink, fontSize: 15)),
              onTap: () => Navigator.pop(sheetContext, _NotificationMenuAction.markAllRead),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: ChatLightColors.ink),
              title: Text(loc.notifMenuDeleteRead, style: const TextStyle(color: ChatLightColors.ink, fontSize: 15)),
              onTap: () => Navigator.pop(sheetContext, _NotificationMenuAction.deleteRead),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: ChatLightColors.ink),
              title: Text(loc.notifMenuSettings, style: const TextStyle(color: ChatLightColors.ink, fontSize: 15)),
              onTap: () => Navigator.pop(sheetContext, _NotificationMenuAction.openSettings),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _NotificationMenuAction.markAllRead:
        final ok = await ref.read(notificationListControllerProvider.notifier).markAllRead();
        if (!mounted) return;
        _showSnack(ok ? loc.notifMarkAllReadDone : loc.notifActionErrorMessage);
      case _NotificationMenuAction.deleteRead:
        final ok = await ref.read(notificationListControllerProvider.notifier).deleteReadNotifications();
        if (!mounted) return;
        _showSnack(ok ? loc.notifDeleteReadDone : loc.notifActionErrorMessage);
      case _NotificationMenuAction.openSettings:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const settings.NotificationsScreen()));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onTapNotification(AppNotification notification) async {
    if (!notification.isRead) {
      ref.read(notificationListControllerProvider.notifier).markRead(notification.id);
    }
    await openNotificationTarget(context, ref, notification);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final state = ref.watch(notificationListControllerProvider);

    return Stack(
      children: [
        const ChatLightBackground(),
        SafeArea(
          child: Column(
            children: [
              _GlassHeader(title: loc.notificationsFeedTitle, onMenuTap: _openMenu),
              Expanded(child: _buildBody(loc, state)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations loc, NotificationListState state) {
    if (state.isInitialLoading) return const _NotificationSkeletonList();

    if (state.error != null) {
      return _NotificationErrorState(error: state.error!, onRetry: () => ref.read(notificationListControllerProvider.notifier).retry());
    }

    if (state.notifications.isEmpty) {
      return _NotificationEmptyState(title: loc.notifEmptyTitle, subtitle: loc.notifEmptySubtitle);
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: state.notifications.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= state.notifications.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.4)),
          );
        }
        final notification = state.notifications[index];
        return _NotificationCard(
          notification: notification,
          loc: loc,
          onTap: () => _onTapNotification(notification),
        );
      },
    );
  }
}

/// A "glass" header row — frosted blur over the translucent light
/// background, echoing the rest of the app's Premium/Apple-leaning
/// chrome without introducing a literal [AppBar] (this tab has no
/// Scaffold of its own; it's embedded in the shared bottom-nav host).
class _GlassHeader extends StatelessWidget {
  final String title;
  final VoidCallback onMenuTap;

  const _GlassHeader({required this.title, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          color: ChatLightColors.bg1.withValues(alpha: 0.55),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
                ),
              ),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: onMenuTap,
                  icon: const Icon(Icons.more_horiz_rounded, color: ChatLightColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Map<NotificationType, IconData> _notificationIcons = {
  NotificationType.newFollower: Icons.person_add_alt_1,
  NotificationType.followRequest: Icons.person_add_alt,
  NotificationType.followAccepted: Icons.how_to_reg_outlined,
  NotificationType.likePost: Icons.favorite,
  NotificationType.commentPost: Icons.mode_comment,
  NotificationType.replyComment: Icons.reply,
  NotificationType.mention: Icons.alternate_email,
  NotificationType.venueOffer: Icons.local_offer,
  NotificationType.venueAdded: Icons.storefront,
  NotificationType.venueVerified: Icons.verified,
  NotificationType.venueSubscriptionDue: Icons.payments_outlined,
  NotificationType.venuePeakHour: Icons.local_fire_department_rounded,
  NotificationType.birthdayMatch: Icons.cake_rounded,
  NotificationType.birthdayOffer: Icons.card_giftcard_rounded,
  NotificationType.waitlistCalled: Icons.notifications_active_rounded,
  NotificationType.waitlistDisabled: Icons.notifications_off_rounded,
  NotificationType.venueEvent: Icons.celebration_rounded,
  NotificationType.vipGranted: Icons.workspace_premium_rounded,
  NotificationType.identityVerificationApproved: Icons.verified,
  NotificationType.identityVerificationRejected: Icons.cancel_rounded,
  NotificationType.productionPost: Icons.movie_creation_outlined,
  NotificationType.venueApproved: Icons.check_circle_rounded,
  NotificationType.offerApproved: Icons.check_circle_rounded,
  NotificationType.venueNeedsRevision: Icons.edit_note_rounded,
  NotificationType.offerNeedsRevision: Icons.edit_note_rounded,
  NotificationType.venueRejected: Icons.cancel_rounded,
  NotificationType.offerRejected: Icons.cancel_rounded,
  NotificationType.pinboxAdded: Icons.inventory_2_outlined,
  NotificationType.pinboxApproved: Icons.check_circle_rounded,
  NotificationType.pinboxRejected: Icons.cancel_rounded,
  NotificationType.pinboxNearby: Icons.inventory_2_outlined,
  NotificationType.system: Icons.info,
  NotificationType.security: Icons.shield,
  NotificationType.promotion: Icons.campaign,
  NotificationType.warning: Icons.warning_amber_rounded,
  NotificationType.announcement: Icons.campaign,
  NotificationType.other: Icons.notifications,
};

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final AppLocalizations loc;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.loc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    // Notifications written after this feature shipped carry `metadata`
    // (type params) and render fully per the app's current language;
    // older ones have none (the server used to write pre-rendered AZ
    // text directly) and fall back to that original text verbatim —
    // deliberately not migrated, see notification_localizer.dart's doc
    // comment.
    final localized = localizeNotification(notification, loc);
    final title = localized?.title ?? notification.title;
    final body = localized?.body ?? notification.body;

    return Material(
      color: isUnread ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationAvatar(notification: notification),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: TextStyle(fontSize: 13, color: ChatLightColors.inkSoft, height: 1.35),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      formatRelativeTime(notification.createdAt, loc),
                      style: TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
                    ),
                  ],
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  final AppNotification notification;

  const _NotificationAvatar({required this.notification});

  @override
  Widget build(BuildContext context) {
    final photo = notification.senderPhoto;
    if (photo != null && photo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        // A sender's photo can 404/403 after the fact (e.g. the account
        // was deleted) — without errorBuilder, Image.network falls back
        // to Flutter's raw broken-image error rendering instead of this
        // screen's own icon placeholder.
        child: AppImage(
          photo,
          thumbnail: true,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
        ),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        _notificationIcons[notification.type] ?? Icons.notifications,
        size: 20,
        color: AppColors.primary,
      ),
    );
  }
}

class _NotificationSkeletonList extends StatelessWidget {
  const _NotificationSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => const _NotificationSkeletonCard(),
    );
  }
}

class _NotificationSkeletonCard extends StatelessWidget {
  const _NotificationSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 44, height: 44, decoration: const BoxDecoration(color: ChatLightColors.cardSurface, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 13, width: 140, color: ChatLightColors.cardSurface),
                const SizedBox(height: 8),
                Container(height: 11, width: double.infinity, color: ChatLightColors.cardSurface),
                const SizedBox(height: 6),
                Container(height: 11, width: 90, color: ChatLightColors.cardSurface),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1400.ms, color: Colors.white);
  }
}

class _NotificationEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _NotificationEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.1)),
              child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 42),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Distinguishes offline / permission-denied / unknown, per the product
/// spec — [isOfflineError]/[isPermissionDeniedError] are the same
/// Firestore-error-code checks the rest of the app uses (see
/// [FriendlyErrorState]); this is a light-themed variant of that same
/// widget's message logic, since [FriendlyErrorState] itself is styled
/// for the app's dark surfaces.
class _NotificationErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _NotificationErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    logError('notifications_feed_screen', error);
    final loc = AppLocalizations.of(context);

    final (icon, title, message) = isOfflineError(error)
        ? (Icons.cloud_off_outlined, loc.notifErrorOfflineTitle, loc.notifErrorOfflineMessage)
        : isPermissionDeniedError(error)
            ? (Icons.lock_outline_rounded, loc.notifErrorPermissionTitle, loc.notifErrorPermissionMessage)
            : (Icons.error_outline_rounded, loc.notifErrorUnknownTitle, loc.notifErrorUnknownMessage);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ChatLightColors.inkFaint, size: 40),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text(loc.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
