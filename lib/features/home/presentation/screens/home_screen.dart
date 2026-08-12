import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calls/presentation/providers/call_providers.dart';
import '../../../calls/presentation/screens/incoming_call_screen.dart';
import '../../../chat/presentation/providers/chat_providers.dart' show totalUnreadChatCountProvider;
import '../../../location/presentation/providers/location_providers.dart';
import '../../../location/presentation/providers/presence_provider.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../../../privacy/presentation/widgets/session_guard.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';
import '../../../settings/notifications/presentation/providers/notification_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart' show notificationListControllerProvider;
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
    final unreadNotificationCount =
        ref.watch(notificationListControllerProvider.select((s) => s.unreadCount));
    final unreadChatCount = ref.watch(totalUnreadChatCountProvider);

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
            child: _LiquidBottomNav(
              selectedIndex: _index,
              onSelect: (i) {
                setState(() => _index = i);
                // Clears the badge the moment the tab is opened, not
                // waiting on each individual notification to be tapped
                // (that path — `_onTapNotification` in
                // `notifications_feed_screen.dart` — still marks its own
                // one read too, this is just the faster common case).
                if (i == 3) {
                  ref.read(notificationListControllerProvider.notifier).markAllRead();
                }
              },
              items: [
                _NavItemData(icon: Icons.explore_outlined, label: loc.navDiscoverLabel),
                _NavItemData(icon: Icons.chat_bubble_outline, label: loc.navChatsLabel, badgeCount: unreadChatCount),
                _NavItemData(icon: Icons.play_circle_outline, label: loc.navFeedLabel),
                _NavItemData(
                  icon: Icons.notifications_outlined,
                  label: loc.navNotificationsLabel,
                  badgeCount: unreadNotificationCount,
                ),
                _NavItemData(icon: Icons.person_outline, label: loc.navProfileLabel),
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
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    // Same outline glyph either way — only the color marks the active
    // tab (the accent), never a filled icon swap.
    final color = selected ? AppColors.primary : AppColors.textMuted;
    final count = badgeCount ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 23),
                if (count > 0)
                  Positioned(
                    right: -7,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.backgroundDark, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700, height: 1),
                      ),
                    ),
                  ),
              ],
            ),
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

class _NavItemData {
  final IconData icon;
  final String label;

  /// Null/0 renders no badge at all — only the Bildirişlər item ever
  /// sets this today (see `HomeScreen.build`'s `unreadNotificationCount`).
  final int? badgeCount;

  const _NavItemData({required this.icon, required this.label, this.badgeCount});
}

/// Drag-to-magnify gesture layer over the nav row — an ADDITIVE layer
/// next to each [_NavItem]'s own `InkWell` tap, not a replacement for
/// it. A plain tap never crosses the pan recognizer's touch-slop, so
/// the arena resolves it straight to `InkWell.onTap` exactly as
/// before; only an actual drag ever reaches [_handlePanUpdate] below.
///
/// Isolated as its own [State] (rather than living on `_HomeScreenState`)
/// so the 60fps `AnimationController` ticks driving the magnify effect
/// only ever rebuild this row, never `HomeScreen`'s `IndexedStack`/tabs.
class _LiquidBottomNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<_NavItemData> items;

  const _LiquidBottomNav({
    required this.selectedIndex,
    required this.onSelect,
    required this.items,
  });

  @override
  State<_LiquidBottomNav> createState() => _LiquidBottomNavState();
}

class _LiquidBottomNavState extends State<_LiquidBottomNav> with SingleTickerProviderStateMixin {
  // How much bigger the magnified tab gets at the drag point (dock-style
  // "peak" scale) — within the requested 1.3-1.5x range.
  static const double _peakScale = 1.4;

  // Soft/elastic, not heavy: a slightly under-damped spring settles in
  // ~250-350ms with a small, natural overshoot rather than a hard snap.
  static const SpringDescription _spring = SpringDescription(mass: 1, stiffness: 350, damping: 24);

  // Drives how strongly the magnify effect is currently applied (0 =
  // off/rest, 1 = fully engaged) — animated via spring simulations, so
  // both the initial "pop" and the release "spring-back" feel elastic.
  late final AnimationController _magnifyController;

  bool _dragging = false;
  bool _inBounds = false;
  double _dragDx = 0;
  int? _lastHapticIndex;

  @override
  void initState() {
    super.initState();
    _magnifyController = AnimationController(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _magnifyController.dispose();
    super.dispose();
  }

  void _animateMagnifyTo(double target) {
    _magnifyController.animateWith(SpringSimulation(_spring, _magnifyController.value, target, 0));
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final rawDx = details.localPosition.dx;
    final rawDy = details.localPosition.dy;
    final inBounds = rawDx >= 0 && rawDx <= size.width && rawDy >= 0 && rawDy <= size.height;

    if (!_dragging) {
      _dragging = true;
      _inBounds = inBounds;
      _animateMagnifyTo(inBounds ? 1 : 0);
    } else if (inBounds != _inBounds) {
      // Deflates in real time if the finger is dragged out of the bar
      // (e.g. swiped upward) without waiting for release, and re-engages
      // if it comes back — same spring either direction.
      _inBounds = inBounds;
      _animateMagnifyTo(inBounds ? 1 : 0);
    }

    final itemWidth = size.width / widget.items.length;
    if (inBounds) {
      final nearest = (rawDx / itemWidth).floor().clamp(0, widget.items.length - 1);
      if (nearest != _lastHapticIndex) {
        _lastHapticIndex = nearest;
        HapticFeedback.selectionClick();
      }
    }

    setState(() => _dragDx = rawDx.clamp(0.0, size.width));
  }

  void _handlePanEnd(Size size) {
    if (_dragging && _inBounds) {
      final itemWidth = size.width / widget.items.length;
      final nearest = (_dragDx / itemWidth).floor().clamp(0, widget.items.length - 1);
      widget.onSelect(nearest);
    }
    _resetDrag();
  }

  void _resetDrag() {
    _dragging = false;
    _inBounds = false;
    _lastHapticIndex = null;
    _animateMagnifyTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final itemWidth = size.width / widget.items.length;
        final sigma = itemWidth * 0.9; // magnify "reach" into neighboring tabs

        return GestureDetector(
          onPanUpdate: (details) => _handlePanUpdate(details, size),
          onPanEnd: (_) => _handlePanEnd(size),
          onPanCancel: _resetDrag,
          child: AnimatedBuilder(
            animation: _magnifyController,
            builder: (context, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(widget.items.length, (i) {
                  final itemCenter = itemWidth * (i + 0.5);
                  final distance = _dragDx - itemCenter;
                  // Gaussian falloff — 1.0 right under the finger, decaying
                  // smoothly toward 0 (i.e. back to normal size) the further
                  // a neighboring tab is, exactly like dock magnification.
                  final falloff = math.exp(-(distance * distance) / (2 * sigma * sigma));
                  final scale = 1 + (_peakScale - 1) * falloff * _magnifyController.value;

                  final item = widget.items[i];
                  return Expanded(
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomCenter,
                      child: _NavItem(
                        icon: item.icon,
                        label: item.label,
                        selected: widget.selectedIndex == i,
                        onTap: () => widget.onSelect(i),
                        badgeCount: item.badgeCount,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        );
      },
    );
  }
}
