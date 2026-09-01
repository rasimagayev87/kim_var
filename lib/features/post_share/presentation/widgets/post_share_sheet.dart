import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/domain/entities/chat.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../data/post_media_cache.dart';
import '../../domain/entities/post.dart';

/// Entry point for the feed's share action — a two-option sheet mirroring
/// [startCreatePostFlow]'s shape: native share sheet (external apps) or
/// picking an existing conversation to send the post into in-app.
void showPostShareOptions(BuildContext context, Post post) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final loc = AppLocalizations.of(sheetContext);
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.postShareOptionsSheetTitle,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.send_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                loc.postShareToChatOption,
                style: AppTextStyles.body.copyWith(fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSendToSheet(context, post);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.ios_share_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                loc.postShareExternalOption,
                style: AppTextStyles.body.copyWith(fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareExternally(context, post);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Opens the native OS share sheet with the post's actual photo/video
/// attached (not just a text link) — AirDrop/Mail/etc. all need a real
/// local file, which [PostReelItem]'s background pre-cache has
/// typically already produced by the time the user gets here (see
/// `PostMediaCache`'s doc comment), so this is usually instant. The
/// loading indicator below is the rare-case fallback, not the common
/// path.
Future<void> _shareExternally(BuildContext context, Post post) async {
  final extension = post.mediaType == PostMediaType.video ? 'mp4' : 'jpg';
  var file = await PostMediaCache.getIfCached(post.mediaUrl);

  if (file == null) {
    if (!context.mounted) return;
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final snackBarController = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 1),
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Text(loc.postSharePreparingMessage),
          ],
        ),
      ),
    );
    try {
      file = await PostMediaCache.getOrDownload(
        post.mediaUrl,
        extension: extension,
      );
    } catch (e, st) {
      logError('post_share_sheet.shareExternally', e, st);
      snackBarController.close();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.postShareErrorMessage)),
        );
      }
      return;
    }
    snackBarController.close();
  }

  await Share.shareXFiles([
    XFile(file.path),
  ], text: post.caption.isNotEmpty ? post.caption : null);
}

void _showSendToSheet(BuildContext context, Post post) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SendToSheet(post: post),
  );
}

class _SendToSheet extends ConsumerWidget {
  final Post post;

  const _SendToSheet({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final chatsAsync = myUid == null
        ? const AsyncValue.data(<Chat>[])
        : ref.watch(chatsProvider);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              loc.postSendToSheetTitle,
              style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: chatsAsync.when(
                data: (chats) {
                  if (chats.isEmpty) {
                    return Center(
                      child: Text(
                        loc.postSendToEmptyMessage,
                        style: AppTextStyles.caption,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chats.length,
                    itemBuilder: (context, index) => _ChatTargetRow(
                      chat: chats[index],
                      myUid: myUid!,
                      post: post,
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, _) => Center(
                  child: Text(
                    loc.postSendToEmptyMessage,
                    style: AppTextStyles.caption,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTargetRow extends ConsumerStatefulWidget {
  final Chat chat;
  final String myUid;
  final Post post;

  const _ChatTargetRow({
    required this.chat,
    required this.myUid,
    required this.post,
  });

  @override
  ConsumerState<_ChatTargetRow> createState() => _ChatTargetRowState();
}

class _ChatTargetRowState extends ConsumerState<_ChatTargetRow> {
  bool _sending = false;

  Future<void> _send(String otherUid) async {
    if (_sending) return;
    setState(() => _sending = true);
    final loc = AppLocalizations.of(context);

    final ok = await ref
        .read(chatControllerProvider.notifier)
        .sendPost(
          otherUid: otherUid,
          postId: widget.post.id,
          mediaUrl: widget.post.mediaUrl,
          isVideo: widget.post.mediaType == PostMediaType.video,
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? loc.postSentToChatSuccessMessage
              : loc.postSentToChatErrorMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final otherUid = widget.chat.otherParticipant(widget.myUid);
    final profile = ref.watch(publicProfileProvider(otherUid)).valueOrNull;
    final name = (profile?.name.isNotEmpty ?? false)
        ? profile!.name
        : loc.defaultUserName;

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.card,
        backgroundImage: profile?.photoUrl != null
            ? NetworkImage(profile!.photoUrl!)
            : null,
        child: profile?.photoUrl == null
            ? const Icon(Icons.person_outline, color: AppColors.textSecondary)
            : null,
      ),
      title: Text(name, style: AppTextStyles.body.copyWith(fontSize: 15)),
      trailing: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : null,
      onTap: _sending ? null : () => _send(otherUid),
    );
  }
}
