import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../location/domain/nearby_user.dart';

enum _SwipeDirection { left, right, up }

/// Tinder-style swipeable stack of [NearbyUser] cards. Takes its data
/// entirely from the caller (the same `nearbyUsersProvider` list used
/// by the map view) — this widget owns no data of its own, only the
/// local swipe/animation state.
///
/// Right swipe / heart button = like, left swipe / X button = reject,
/// star button = super-like. Swiped users are hidden locally by id so
/// upstream list refreshes (position or Firestore updates) don't reset
/// progress or resurface an already-swiped person.
class NearbyUserCardStack extends StatefulWidget {
  final List<NearbyUser> users;

  const NearbyUserCardStack({super.key, required this.users});

  @override
  State<NearbyUserCardStack> createState() => _NearbyUserCardStackState();
}

class _NearbyUserCardStackState extends State<NearbyUserCardStack>
    with SingleTickerProviderStateMixin {
  final Set<String> _handledIds = {};
  Offset _dragOffset = Offset.zero;
  late final AnimationController _flingController;
  Animation<Offset>? _flingAnimation;

  List<NearbyUser> get _visibleUsers =>
      widget.users.where((u) => !_handledIds.contains(u.id)).toList();

  @override
  void initState() {
    super.initState();
    _flingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (_flingAnimation != null) {
          setState(() => _dragOffset = _flingAnimation!.value);
        }
      });
  }

  @override
  void dispose() {
    _flingController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    const threshold = 110.0;
    if (_dragOffset.dx > threshold) {
      _swipeTop(_SwipeDirection.right);
    } else if (_dragOffset.dx < -threshold) {
      _swipeTop(_SwipeDirection.left);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _flingAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _flingController, curve: Curves.easeOut),
    );
    _flingController.forward(from: 0);
  }

  void _swipeTop(_SwipeDirection direction) {
    final current = _visibleUsers;
    if (current.isEmpty) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final target = switch (direction) {
      _SwipeDirection.right => Offset(screenWidth * 1.5, _dragOffset.dy),
      _SwipeDirection.left => Offset(-screenWidth * 1.5, _dragOffset.dy),
      _SwipeDirection.up => Offset(_dragOffset.dx, -screenWidth * 1.5),
    };

    _flingAnimation = Tween<Offset>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _flingController, curve: Curves.easeIn),
    );
    final swipedId = current.first.id;
    _flingController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _handledIds.add(swipedId);
        _dragOffset = Offset.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _visibleUsers.take(3).toList();

    if (remaining.isEmpty) {
      return const _EmptyStack();
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = remaining.length - 1; i >= 0; i--)
                if (i == 0) _buildTopCard(remaining[0]) else _buildBackgroundCard(remaining[i], i),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionButtons(
          onReject: () => _swipeTop(_SwipeDirection.left),
          onSuperLike: () => _swipeTop(_SwipeDirection.up),
          onLike: () => _swipeTop(_SwipeDirection.right),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBackgroundCard(NearbyUser user, int depth) {
    final scale = 1 - (depth * 0.04);
    return Transform.scale(
      scale: scale,
      child: Padding(
        padding: EdgeInsets.only(top: depth * 10),
        child: _NearbyUserCard(user: user),
      ),
    );
  }

  Widget _buildTopCard(NearbyUser user) {
    final rotation = _dragOffset.dx / 300;
    final likeOpacity = (_dragOffset.dx / 120).clamp(0.0, 1.0);
    final rejectOpacity = (-_dragOffset.dx / 120).clamp(0.0, 1.0);
    final superOpacity = (-_dragOffset.dy / 120).clamp(0.0, 1.0);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: rotation,
          child: Stack(
            children: [
              _NearbyUserCard(user: user),
              Positioned(
                top: 24,
                left: 24,
                child: Opacity(
                  opacity: likeOpacity,
                  child: const _StampBadge(label: 'BƏYƏN', color: AppColors.primary),
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                child: Opacity(
                  opacity: rejectOpacity,
                  child: const _StampBadge(label: 'İMTİNA', color: AppColors.error),
                ),
              ),
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: superOpacity,
                    child: const _StampBadge(label: 'SUPER', color: Colors.blueAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyUserCard extends StatelessWidget {
  final NearbyUser user;

  const _NearbyUserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (user.photoUrl != null)
            Image.network(user.photoUrl!, fit: BoxFit.cover)
          else
            const ColoredBox(
              color: AppColors.surface,
              child: Icon(Icons.person, size: 96, color: AppColors.primary),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.age != null ? '${user.name}, ${user.age}' : user.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(_formatDistance(user.distanceMeters), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                  if (user.mainInterest.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(user.mainInterest, style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDistance(double meters) {
  return meters < 1000 ? '${meters.round()} m aralı' : '${(meters / 1000).toStringAsFixed(1)} km aralı';
}

class _StampBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StampBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(10),
        color: AppColors.backgroundDark.withOpacity(0.4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.5),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onSuperLike;
  final VoidCallback onLike;

  const _ActionButtons({required this.onReject, required this.onSuperLike, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundActionButton(icon: Icons.close, color: AppColors.error, size: 56, onTap: onReject),
        const SizedBox(width: 20),
        _RoundActionButton(icon: Icons.star, color: Colors.blueAccent, size: 46, onTap: onSuperLike),
        const SizedBox(width: 20),
        _RoundActionButton(icon: Icons.favorite, color: AppColors.primary, size: 56, onTap: onLike),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12, spreadRadius: 1)],
        ),
        child: Icon(icon, color: color, size: size * 0.46),
      ),
    );
  }
}

class _EmptyStack extends StatelessWidget {
  const _EmptyStack();

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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                boxShadow: [BoxShadow(color: AppColors.glow, blurRadius: 40, spreadRadius: 4)],
              ),
              child: const Icon(Icons.people_outline, color: AppColors.primary, size: 42),
            ),
            const SizedBox(height: 22),
            const Text(
              'Ətrafında hələ kimsə yoxdur',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              'Radius və ya filtri dəyişməyi sınayın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
