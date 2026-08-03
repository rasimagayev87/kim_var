import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/post.dart';

void showPostShareOptions(BuildContext context, Post post) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PostShareOptionsSheet(post: post),
  );
}

class _PostShareOptionsSheet extends StatelessWidget {
  final Post post;

  const _PostShareOptionsSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(loc.postShareOptionsSheetTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            title: Text(loc.postShareToChatOption, style: AppTextStyles.body),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: AppColors.surface,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => _SendToChatSheet(post: post),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share, color: AppColors.primary),
            title: Text(loc.postShareExternalOption, style: AppTextStyles.body),
            onTap: () {
              Navigator.pop(context);
              Share.share(post.mediaUrl);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SendToChatSheet extends ConsumerWidget {
  final Post post;

  const _SendToChatSheet({required this.post});

  Stream<List<String>> _chatPartnerIds(String myUid) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => (doc.data()['participants'] as List).cast<String>().firstWhere(
                  (id) => id != myUid,
                  orElse: () => '',
                ))
            .where((id) => id.isNotEmpty)
            .toList());
  }

  Future<void> _sendToChat(BuildContext context, WidgetRef ref, String myUid, String otherUid) async {
    final loc = AppLocalizations.of(context)!;
    final ids = [myUid, otherUid]..sort();
    final chatId = ids.join('_');

    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      await chatRef.set({
        'participants': [myUid, otherUid],
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderId': myUid,
        'receiverId': otherUid,
        'type': 'post',
        'targetId': post.id,
        'text': post.caption,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postSentToChatSuccessMessage)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postSentToChatErrorMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(loc.postSendToSheetTitle, style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: _chatPartnerIds(myUid),
                builder: (context, snapshot) {
                  final partnerIds = snapshot.data ?? const [];
                  if (partnerIds.isEmpty) {
                    return Center(child: Text(loc.postSendToEmptyMessage, style: AppTextStyles.caption));
                  }
                  return ListView.builder(
                    itemCount: partnerIds.length,
                    itemBuilder: (context, index) {
                      final otherUid = partnerIds[index];
                      final profile = ref.watch(publicProfileProvider(otherUid)).valueOrNull;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.card,
                          backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
                          child: profile?.photoUrl == null ? const Icon(Icons.person_outline, color: AppColors.textSecondary) : null,
                        ),
                        title: Text(profile?.name ?? loc.defaultUserName, style: AppTextStyles.body),
                        onTap: () => _sendToChat(context, ref, myUid, otherUid),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
