import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../providers/post_providers.dart';

void showCommentsSheet(BuildContext context, String postId) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
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
  final _textController = TextEditingController();
  PostComment? _replyingTo;
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final loc = AppLocalizations.of(context)!;
    if (!await requireVerified(context, ref)) return;
    if (!mounted) return;

    setState(() => _sending = true);
    final ok = await ref.read(postControllerProvider).addComment(
          widget.postId,
          text,
          replyToCommentId: _replyingTo?.id,
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _textController.clear();
        _replyingTo = null;
      }
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postCommentErrorMessage)));
    }
  }

  Future<void> _confirmDelete(PostComment comment) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(loc.postCommentDeleteConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(loc.actionDelete)),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(postControllerProvider).deleteComment(widget.postId, comment.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postCommentDeleteErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final commentsAsync = ref.watch(commentsForPostProvider(widget.postId));
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text(loc.postCommentsSheetTitle, style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              Expanded(
                child: commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Center(child: Text(loc.postCommentsEmptyMessage, style: AppTextStyles.caption));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final profile = ref.watch(publicProfileProvider(comment.userId)).valueOrNull;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.card,
                            backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
                            child: profile?.photoUrl == null ? const Icon(Icons.person_outline, color: AppColors.textSecondary) : null,
                          ),
                          title: Text(profile?.name ?? loc.defaultUserName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment.text, style: AppTextStyles.body),
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                                onPressed: () => setState(() => _replyingTo = comment),
                                child: Text(loc.postReplyAction, style: AppTextStyles.caption),
                              ),
                            ],
                          ),
                          trailing: comment.userId == currentUid
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                                  onPressed: () => _confirmDelete(comment),
                                )
                              : null,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (_, _) => Center(child: Text(loc.postCommentErrorMessage, style: AppTextStyles.caption)),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_replyingTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  loc.postReplyingToLabel(
                                    ref.watch(publicProfileProvider(_replyingTo!.userId)).valueOrNull?.name ??
                                        loc.defaultUserName,
                                  ),
                                  style: AppTextStyles.caption,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                onPressed: () => setState(() => _replyingTo = null),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: AppTextStyles.body,
                              decoration: InputDecoration(hintText: loc.postCommentHint),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.send_rounded, color: AppColors.primary),
                            onPressed: _sending ? null : _send,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
