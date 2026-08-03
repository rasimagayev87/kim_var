import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../post_share/presentation/providers/post_providers.dart';
import '../providers/public_profile_providers.dart';

/// Read-only view of another user's profile — reached from a post
/// author's avatar in the feed, a comment author, etc.
class UserProfileScreen extends ConsumerWidget {
  final String uid;

  const UserProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(uid));
    final postsAsync = ref.watch(postsByUserProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: profileAsync.valueOrNull != null ? Text(profileAsync.valueOrNull!.name) : null),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.card,
                backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                child: profile.photoUrl == null
                    ? const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 44)
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(profile.name, style: AppTextStyles.cardTitle),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: AppColors.primary, size: 18),
                  ],
                ],
              ),
            ),
            if (profile.username != null)
              Center(
                child: Text('@${profile.username}', style: AppTextStyles.caption),
              ),
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(profile.bio, textAlign: TextAlign.center, style: AppTextStyles.body),
            ],
            if ((profile.country ?? '').isNotEmpty || (profile.city ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_outlined, color: AppColors.textSecondary, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      [profile.city, profile.country].where((v) => (v ?? '').isNotEmpty).join(', '),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) return const SizedBox.shrink();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: posts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: post.mediaType.name == 'video'
                          ? Container(
                              color: AppColors.card,
                              alignment: Alignment.center,
                              child: const Icon(Icons.play_arrow_rounded, color: AppColors.textSecondary),
                            )
                          : Image.network(
                              post.mediaUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const PhotoPlaceholderPattern(),
                            ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => const Center(child: Icon(Icons.error_outline, color: AppColors.error)),
      ),
    );
  }
}
