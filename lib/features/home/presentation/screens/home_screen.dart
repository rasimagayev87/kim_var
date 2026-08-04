import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calls/presentation/providers/call_providers.dart';
import '../../../calls/presentation/screens/incoming_call_screen.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../location/presentation/providers/presence_provider.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../../../privacy/presentation/widgets/session_guard.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';
import '../../../settings/notifications/presentation/providers/notification_providers.dart';
import '../../../notifications/presentation/screens/notifications_feed_screen.dart';
import '../tabs/chats_tab.dart';
import '../tabs/discover_tab.dart';
import '../tabs/feed_tab.dart';
import '../tabs/profile_tab.dart';

/// Total height of the nav row (icon + label-height spacer + vertical
/// padding). SafeArea's bottom inset is added on top of this, not
/// squeezed into it.
const double _kNavBarHeight = 66;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;

  // Guards against re-pushing IncomingCallScreen for the same ringing
  // call on every unrelated snapshot re-emission (CallSession has no
  // value equality, so previous != next on every emission otherwise) —
  // reset to null once the call stops being ringing, so a genuinely
  // new call afterwards still triggers a fresh push.
  String? _handledIncomingCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(presenceControllerProvider).setOnline();
    ref.read(deviceSessionControllerProvider).touchCurrentSession();
    ref.read(notificationPreferencesControllerProvider).syncSubscriptions();
    _applySavedGpsAccuracy();
  }

  /// Applies the saved GPS dəqiqliyi preference to the live
  /// [LocationController] once at startup — [LocationController]
  /// defaults to high accuracy before this resolves.
  Future<void> _applySavedGpsAccuracy() async {
    try {
      final settings = await ref.read(mapLocationSettingsProvider.future);
      if (!mounted) return;
      ref.read(locationControllerProvider.notifier).applyAccuracy(toLocationAccuracy(settings.gpsAccuracy));
    } catch (_) {
      // Non-fatal — LocationController's high-accuracy default stands.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(presenceControllerProvider).setOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final presence = ref.read(presenceControllerProvider);
    if (state == AppLifecycleState.resumed) {
      presence.setOnline();
      ref.read(deviceSessionControllerProvider).touchCurrentSession();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      presence.setOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    ref.listen(incomingCallProvider, (previous, next) {
      final session = next.valueOrNull;
      if (session == null) {
        _handledIncomingCallId = null;
        return;
      }
      if (_handledIncomingCallId == session.id) return;
      _handledIncomingCallId = session.id;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => IncomingCallScreen(session: session)));
    });

    return SessionGuard(
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          const DiscoverTab(),
          const ChatsTab(),
          FeedTab(active: _index == 2),
          const NotificationsFeedScreen(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        // SafeArea wraps the whole reserved bar height at the outermost
        // level, so its bottom inset is *added on top* of a natural size
        // instead of being squeezed into a hardcoded total.
        //
        // The center "+" used to be a Positioned overlay floating above the
        // row, which visually sat higher than the other tab icons. It's now
        // a regular Row item like the rest: every item shares the exact
        // same [icon/button] -> 4px gap -> label-height-spacer structure, so
        // whatever each item's icon size is, its optical center lands the
        // same distance from the row's vertical center for all five items
        // — alignment falls out of the shared layout instead of a hand
        // -tuned pixel offset.
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: _kNavBarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.explore_outlined,
                    label: loc.navDiscoverLabel,
                    selected: _index == 0,
                    onTap: () => setState(() => _index = 0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.chat_bubble_outline,
                    label: loc.navChatsLabel,
                    selected: _index == 1,
                    onTap: () => setState(() => _index = 1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.play_circle_outline,
                    label: loc.navFeedLabel,
                    selected: _index == 2,
                    onTap: () => setState(() => _index = 2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.notifications_outlined,
                    label: loc.navNotificationsLabel,
                    selected: _index == 3,
                    onTap: () => setState(() => _index = 3),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    label: loc.navProfileLabel,
                    selected: _index == 4,
                    onTap: () => setState(() => _index = 4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Height every nav row item is padded/spaced to build against, so each
/// [_NavItem]'s icon lands on the same optical center (see [_kNavBarHeight]).
const double _kNavIconGap = 4;

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Same outline glyph either way — only the color marks the active
    // tab (the accent), never a filled icon swap.
    final color = selected ? AppColors.primary : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: _kNavIconGap),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
