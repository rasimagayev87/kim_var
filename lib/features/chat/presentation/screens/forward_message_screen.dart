import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_providers.dart';
import '../theme/chat_light_theme.dart';

const _kMaxForwardTargets = 5;

/// Opened from a message's long-press menu ("Yönləndir") — lists the
/// user's existing chat contacts (forwarding never starts a conversation
/// with someone new, only reuses ones that already exist), lets them
/// pick up to [_kMaxForwardTargets], then re-sends the message's
/// existing content into each selected chat.
class ForwardMessageScreen extends ConsumerStatefulWidget {
  final ChatMessage message;

  const ForwardMessageScreen({super.key, required this.message});

  @override
  ConsumerState<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends ConsumerState<ForwardMessageScreen> {
  final Set<String> _selected = {};
  bool _sending = false;

  void _toggle(String otherUid) {
    setState(() {
      if (_selected.contains(otherUid)) {
        _selected.remove(otherUid);
      } else if (_selected.length < _kMaxForwardTargets) {
        _selected.add(otherUid);
      }
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);

    final success = await ref.read(chatControllerProvider.notifier).forwardMessage(
          message: widget.message,
          targetOtherUids: _selected.toList(),
        );

    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatForwardSuccessMessage)));
    } else {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatRequestActionErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final chatsAsync = myUid == null ? const AsyncValue<List<Chat>>.data([]) : ref.watch(chatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ChatLightColors.ink,
        title: Text(loc.chatForwardTitle, style: const TextStyle(color: ChatLightColors.ink)),
      ),
      body: myUid == null
          ? const SizedBox.shrink()
          : chatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: ChatLightColors.inkSoft))),
              data: (chats) {
                if (chats.isEmpty) {
                  return Center(
                    child: Text(loc.chatForwardEmptyMessage, style: const TextStyle(color: ChatLightColors.inkFaint)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final otherUid = chats[index].otherParticipant(myUid);
                    return _ForwardTargetRow(
                      otherUid: otherUid,
                      selected: _selected.contains(otherUid),
                      onTap: () => _toggle(otherUid),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                        )
                      : Text(loc.chatForwardSendButton(_selected.length)),
                ),
              ),
            ),
    );
  }
}

class _ForwardTargetRow extends ConsumerWidget {
  final String otherUid;
  final bool selected;
  final VoidCallback onTap;

  const _ForwardTargetRow({required this.otherUid, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final peer = ref.watch(publicProfileProvider(otherUid)).valueOrNull;
    final name = (peer?.name ?? '').isEmpty ? loc.defaultUserName : peer!.name;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: ChatLightColors.cardSurface,
        backgroundImage: peer?.photoUrl != null ? NetworkImage(peer!.photoUrl!) : null,
        child: peer?.photoUrl == null ? const Icon(Icons.person, color: ChatLightColors.inkFaint) : null,
      ),
      title: Text(name, style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w600)),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? AppColors.primary : ChatLightColors.inkFaint,
      ),
    );
  }
}
