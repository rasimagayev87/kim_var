import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../domain/entities/post.dart';
import '../providers/post_providers.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/post_owner_menu_button.dart';
import '../widgets/post_video_player.dart';

/// Single-post view opened by tapping a card in the profile feed.
/// Owner-only "..." menu (top-right) offers editing the caption — the
/// only field a post can be edited after sharing — or deleting it.
class PostDetailScreen extends ConsumerWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final postAsync = ref.watch(postByIdProvider(postId));
    final post = postAsync.valueOrNull;
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = post != null && myUid != null && post.userId == myUid;
    final isLiked = ref.watch(isPostLikedByMeProvider(postId)).valueOrNull ?? false;

    Future<void> onLikeTap() async {
      if (!await requireVerified(context, ref)) return;
      if (!context.mounted) return;
      final ok = await ref.read(postControllerProvider).toggleLike(postId, !isLiked);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postLikeErrorMessage)));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        actions: [if (isOwner) PostOwnerMenuButton(post: post)],
      ),
      body: post == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: ListView(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: post.mediaType == PostMediaType.photo
                        ? Image.network(
                            post.mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const PhotoPlaceholderPattern(),
                          )
                        : PostVideoThumbnail(videoUrl: post.mediaUrl),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: onLikeTap,
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 22,
                                color: isLiked ? Colors.redAccent : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.likesCount}',
                              style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => showCommentsSheet(context, postId),
                              child: const Icon(Icons.mode_comment_outlined, size: 21, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.commentsCount}',
                              style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (post.caption.isNotEmpty) ...[
                          Text(post.caption, style: AppTextStyles.body.copyWith(fontSize: 15, height: 1.5)),
                          const SizedBox(height: 8),
                        ],
                        Text(formatRelativeTime(post.createdAt, loc), style: AppTextStyles.caption.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
