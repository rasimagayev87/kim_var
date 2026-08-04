import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/post_comment.dart';
import '../providers/post_providers.dart';

void showCommentsSheet(BuildContext context, String postId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CommentsSheet(postId: postId),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final String postId;

  const _CommentsSheet({required this.postId});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  /// The comment being replied to, if any — mutually exclusive with
  /// [_editingComment] (only one compose mode active at a time).
  PostComment? _replyingTo;
  PostComment? _editingComment;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startReply(PostComment comment) {
    setState(() {
      _replyingTo = comment;
      _editingComment = null;
      _controller.clear();
    });
  }

  void _startEdit(PostComment comment) {
    setState(() {
      _editingComment = comment;
      _replyingTo = null;
      _controller.text = comment.text;
    });
  }

  void _cancelComposeMode() {
    setState(() {
      _replyingTo = null;
      _editingComment = null;
      _controller.clear();
    });
  }

  Future<void> _send(AppLocalizations loc) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final editing = _editingComment;
    // Only gate NEW comments/replies — editing your own existing
    // comment isn't a new interaction and stays available regardless.
    if (editing == null && !await requireVerified(context, ref)) return;
    if (!mounted) return;
    setState(() => _sending = true);

    final ok = editing != null
        ? await ref.read(postControllerProvider).updateComment(widget.postId, editing.id, text)
        : await ref.read(postControllerProvider).addComment(widget.postId, text, replyToCommentId: _replyingTo?.id);

    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      _controller.clear();
      setState(() {
        _replyingTo = null;
        _editingComment = null;
      });
      FocusScope.of(context).unfocus();
    } else {
      final message = editing != null ? loc.postCommentEditErrorMessage : loc.postCommentErrorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final postOwnerId = ref.watch(postByIdProvider(widget.postId)).valueOrNull?.userId;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(loc.postCommentsSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Center(child: Text(loc.postCommentsEmptyMessage, style: AppTextStyles.caption));
                    }
                    final topLevel = comments.where((c) => c.replyToCommentId == null).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: topLevel.length,
                      itemBuilder: (context, index) {
                        final comment = topLevel[index];
                        final replies = comments.where((c) => c.replyToCommentId == comment.id).toList();
                        return _CommentThread(
                          postId: widget.postId,
                          comment: comment,
                          replies: replies,
                          postOwnerId: postOwnerId,
                          onReply: _startReply,
                          onEdit: _startEdit,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (_, _) => Center(child: Text(loc.postCommentsEmptyMessage, style: AppTextStyles.caption)),
                ),
              ),
              if (_replyingTo != null || _editingComment != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editingComment != null
                              ? loc.postMenuEdit
                              : loc.postReplyingToLabel(_ReplyTargetName(userId: _replyingTo!.userId).resolve(ref)),
                          style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelComposeMode,
                        child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: AppTextStyles.body.copyWith(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: loc.postCommentHint,
                          filled: true,
                          fillColor: AppColors.card,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : () => _send(loc),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.send_outlined, color: AppColors.primary),
                    ),
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

/// Small helper so the "Replying to X" label can resolve a display
/// name from a uid without turning the whole sheet into a
/// ConsumerWidget rebuild just for that one string.
class _ReplyTargetName {
  final String userId;

  const _ReplyTargetName({required this.userId});

  String resolve(WidgetRef ref) {
    final profile = ref.read(publicProfileProvider(userId)).valueOrNull;
    return profile?.name ?? '';
  }
}

class _CommentThread extends StatelessWidget {
  final String postId;
  final PostComment comment;
  final List<PostComment> replies;
  final String? postOwnerId;
  final void Function(PostComment) onReply;
  final void Function(PostComment) onEdit;

  const _CommentThread({
    required this.postId,
    required this.comment,
    required this.replies,
    required this.postOwnerId,
    required this.onReply,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(
          postId: postId,
          comment: comment,
          postOwnerId: postOwnerId,
          isReply: false,
          onReply: onReply,
          onEdit: onEdit,
        ),
        for (final reply in replies)
          _CommentRow(
            postId: postId,
            comment: reply,
            postOwnerId: postOwnerId,
            isReply: true,
            onReply: null,
            onEdit: onEdit,
          ),
      ],
    );
  }
}

enum _CommentMenuAction { edit, delete }

class _CommentRow extends ConsumerWidget {
  final String postId;
  final PostComment comment;
  final String? postOwnerId;
  final bool isReply;

  /// Null for a reply — Instagram-style threading only ever goes one
  /// level deep, so replies don't offer their own "reply" action.
  final void Function(PostComment)? onReply;
  final void Function(PostComment) onEdit;

  const _CommentRow({
    required this.postId,
    required this.comment,
    required this.postOwnerId,
    required this.isReply,
    required this.onReply,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final profile = ref.watch(publicProfileProvider(comment.userId)).valueOrNull;
    final name = (profile?.name.isNotEmpty ?? false) ? profile!.name : loc.defaultUserName;
    final isLiked = ref.watch(isCommentLikedByMeProvider((postId, comment.id))).valueOrNull ?? false;

    final canEdit = myUid != null && myUid == comment.userId;
    final canDelete = myUid != null && (myUid == comment.userId || myUid == postOwnerId);

    Future<void> onLikeTap() async {
      if (!await requireVerified(context, ref)) return;
      if (!context.mounted) return;
      final ok = await ref.read(postControllerProvider).toggleCommentLike(postId, comment.id, !isLiked);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postLikeErrorMessage)));
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 40 : 0, top: 10, bottom: 2),
      child: GestureDetector(
        onLongPress: (canEdit || canDelete) ? () => _showMenu(context, ref, loc, canEdit, canDelete) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 14 : 16,
              backgroundColor: AppColors.card,
              backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
              child: profile?.photoUrl == null
                  ? Icon(Icons.person_outline, color: AppColors.textSecondary, size: isReply ? 14 : 16)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyles.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(formatRelativeTime(comment.createdAt, loc), style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment.text, style: AppTextStyles.body.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (comment.likesCount > 0) ...[
                        Text(
                          '${comment.likesCount}',
                          style: AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (onReply != null)
                        GestureDetector(
                          onTap: () => onReply!(comment),
                          child: Text(
                            loc.postReplyAction,
                            style: AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onLikeTap,
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: isReply ? 13 : 15,
                color: isLiked ? Colors.redAccent : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref, AppLocalizations loc, bool canEdit, bool canDelete) {
    showModalBottomSheet<_CommentMenuAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                  title: Text(loc.postMenuEdit, style: AppTextStyles.body.copyWith(fontSize: 15)),
                  onTap: () => Navigator.pop(sheetContext, _CommentMenuAction.edit),
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text(loc.postMenuDelete, style: AppTextStyles.body.copyWith(fontSize: 15, color: AppColors.error)),
                  onTap: () => Navigator.pop(sheetContext, _CommentMenuAction.delete),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).then((action) {
      if (!context.mounted || action == null) return;
      switch (action) {
        case _CommentMenuAction.edit:
          onEdit(comment);
        case _CommentMenuAction.delete:
          _confirmDelete(context, ref, loc);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AppLocalizations loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.postCommentDeleteConfirmTitle, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
        content: Text(loc.postDeleteConfirmMessage, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.postMenuDelete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(postControllerProvider).deleteComment(postId, comment.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postCommentDeleteErrorMessage)));
    }
  }
}
