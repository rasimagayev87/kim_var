import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';

/// In-bubble preview for a shared "Lent" post — a static thumbnail
/// (photo posts only; video posts show a plain play-icon placeholder,
/// same "no inline video decoding in a bubble" rule as
/// [VideoMessageBubble]) plus a label row, tapping opens the full post.
class PostMessageBubble extends StatelessWidget {
  final String postId;
  final String? thumbnailUrl;
  final bool isVideo;
  final VoidCallback onTap;

  const PostMessageBubble({
    super.key,
    required this.postId,
    required this.thumbnailUrl,
    required this.isVideo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: (!isVideo && thumbnailUrl != null)
                    ? AppImage(
                        thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _ThumbnailFallback(isVideo: isVideo),
                      )
                    : _ThumbnailFallback(isVideo: isVideo),
              ),
              Container(
                width: 180,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: AppColors.backgroundDark,
                child: Row(
                  children: [
                    const Icon(Icons.attachment_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc.chatPostMessageLabel,
                        style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  final bool isVideo;

  const _ThumbnailFallback({required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      child: Icon(isVideo ? Icons.play_circle_outline : Icons.image_outlined, color: AppColors.textMuted, size: 32),
    );
  }
}
