import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../privacy/domain/entities/privacy_settings.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../providers/follow_providers.dart';

/// Follow button with 3 states: not following ("İzlə"), a still-pending
/// request the SIGNED-IN user themselves sent ("İstək göndərildi" —
/// disabled, tapping again does nothing until the followee decides),
/// and following ("İzləyir"). Which of the first two a fresh tap
/// produces depends on [otherUid]'s own `AccountPrivacy` (see
/// `FollowController.toggleFollow`). Unfollowing (tapping while already
/// following) asks for confirmation first — shared by
/// `UserProfileScreen`'s own action row and every followers/following
/// list row that isn't the signed-in user's own list.
class FollowButton extends ConsumerWidget {
  final String otherUid;
  final String displayName;

  const FollowButton({super.key, required this.otherUid, required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const SizedBox.shrink();

    final isFollowing = ref.watch(isFollowingProvider(otherUid)).valueOrNull ?? false;
    final isPending = ref.watch(isPendingFollowRequestProvider(otherUid)).valueOrNull ?? false;
    final privacy = ref.watch(otherUserPrivacySettingsProvider(otherUid)).valueOrNull ?? const PrivacySettings();

    final label = isFollowing
        ? loc.followingButton
        : isPending
            ? loc.followRequestSentLabel
            : loc.followButton;

    return ProfileActionButton(
      label: label,
      tonal: isFollowing || isPending,
      onPressed: isPending
          ? null
          : () async {
              if (isFollowing) {
                final confirmed = await _confirmUnfollow(context, loc, displayName);
                if (confirmed != true || !context.mounted) return;
              }
              final success = await ref.read(followControllerProvider).toggleFollow(
                    otherUid: otherUid,
                    isCurrentlyFollowing: isFollowing,
                    isCurrentlyPending: isPending,
                    otherAccountIsPrivate: privacy.accountPrivacy == AccountPrivacy.private,
                  );
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.followErrorMessage)));
              }
            },
    );
  }
}

Future<bool?> _confirmUnfollow(BuildContext context, AppLocalizations loc, String displayName) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(loc.unfollowButton, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(loc.unfollowConfirmMessage(displayName)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(loc.unfollowButton),
        ),
      ],
    ),
  );
}

/// Thin, minimal (no icon) pill button — `tonal: false` is the solid
/// app-accent fill (before following/acting); `tonal: true` is the
/// same pale accent-tinted wash used once already following, and for
/// secondary actions (Message, etc.) alongside it.
class ProfileActionButton extends StatelessWidget {
  final String label;
  final bool tonal;
  final VoidCallback? onPressed;

  const ProfileActionButton({super.key, required this.label, required this.tonal, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final background = tonal ? AppColors.primary.withValues(alpha: 0.12) : AppColors.primary;
    final foreground = tonal ? AppColors.primary : AppColors.onAccent;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w600, color: foreground),
          ),
        ),
      ),
    );
  }
}
