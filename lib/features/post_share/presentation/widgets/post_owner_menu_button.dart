import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/post.dart';
import '../providers/post_providers.dart';

/// Owner-only "..." menu — edit caption (the only field a post can be
/// edited after sharing) or delete it. Shared by [PostDetailScreen]
/// and [PostReelViewerScreen] so a post owner gets the same controls
/// regardless of which screen they're viewing their own post from.
class PostOwnerMenuButton extends ConsumerWidget {
  final Post post;
  final Color iconColor;

  const PostOwnerMenuButton({super.key, required this.post, this.iconColor = AppColors.white});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);

    return PopupMenuButton<_PostMenuAction>(
      icon: Icon(Icons.more_vert_outlined, color: iconColor),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (action) {
        switch (action) {
          case _PostMenuAction.edit:
            _showEditCaptionSheet(context, post);
          case _PostMenuAction.delete:
            _confirmDelete(context, ref, post);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _PostMenuAction.edit,
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(loc.postMenuEdit, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PostMenuAction.delete,
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              Text(loc.postMenuDelete, style: AppTextStyles.body.copyWith(fontSize: 14.5, color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditCaptionSheet(BuildContext context, Post post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditCaptionSheet(post: post),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Post post) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.postDeleteConfirmTitle, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
        content: Text(loc.postDeleteConfirmMessage, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.postMenuDelete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Captured before the delete's await gap: deleting the Firestore doc
    // makes postByIdProvider/feedPostsProvider emit without this post
    // immediately, which can unmount this very button (and its context)
    // while the storage cleanup below is still in flight. Navigator.of
    // (context)/ScaffoldMessenger.of(context) called *after* the await
    // would then silently no-op, leaving the caller stuck.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await ref.read(postControllerProvider).deletePost(post.id, post.mediaUrl, thumbnailUrl: post.thumbnailUrl);
    if (ok) {
      navigator.pop();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(loc.postDeleteErrorMessage)));
    }
  }
}

enum _PostMenuAction { edit, delete }

class _EditCaptionSheet extends ConsumerStatefulWidget {
  final Post post;

  const _EditCaptionSheet({required this.post});

  @override
  ConsumerState<_EditCaptionSheet> createState() => _EditCaptionSheetState();
}

class _EditCaptionSheetState extends ConsumerState<_EditCaptionSheet> {
  late final _controller = TextEditingController(text: widget.post.caption);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations loc) async {
    if (_saving) return;
    setState(() => _saving = true);

    final ok = await ref.read(postControllerProvider).updateCaption(widget.post.id, _controller.text.trim());

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postEditCaptionErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.postEditCaptionTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 2,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: loc.postCaptionHint,
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(loc),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.onAccent),
                      )
                    : Text(loc.postEditCaptionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
