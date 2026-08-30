import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/friendly_error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/domain/entities/chat.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../chat/presentation/screens/chat_conversation_screen.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../location/presentation/providers/presence_provider.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';

enum _ChatFilter { all, unread, archived, requests }

/// Collapses the Azerbaijani/Turkish İ/I/ı family down to plain ASCII
/// 'i' on both sides of a search comparison. Dart's `String.toLowerCase()`
/// uses locale-unaware Unicode casing, where 'İ' (dotted capital I)
/// lowercases to 'i' + a combining dot-above — NOT the plain 'i' a typed
/// query normally contains — so without this, searching a name/message
/// containing 'İ' (extremely common in Azerbaijani) silently never
/// matches.
String _azSearchKey(String value) {
  return value.replaceAll('İ', 'i').replaceAll('I', 'i').replaceAll('ı', 'i').toLowerCase();
}

sealed class _ChatRow {
  const _ChatRow();
}

class _SectionHeaderRow extends _ChatRow {
  final String label;
  final IconData? icon;
  const _SectionHeaderRow(this.label, {this.icon});
}

class _ChatRowItem extends _ChatRow {
  final Chat chat;
  const _ChatRowItem(this.chat);
}

class ChatsTab extends ConsumerStatefulWidget {
  const ChatsTab({super.key});

  @override
  ConsumerState<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<ChatsTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  _ChatFilter _filter = _ChatFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(chatListControllerProvider.notifier).loadMore();
    }
  }

  /// Chip filter first (only touches [Chat] fields, no extra reads),
  /// then the search query — which needs each candidate's resolved
  /// profile, so it's the only branch that watches `publicProfileProvider`
  /// at this level. Left empty (the common case), zero extra reads
  /// happen here at all.
  List<Chat> _visibleChats(List<Chat> all, String myUid) {
    var result = all.where((chat) {
      // A still-pending request the current user hasn't responded to
      // lives exclusively under Sorğular — it never mixes into
      // Hamısı/Oxunmayanlar/Arxivlənənlər until accepted (or declined,
      // at which point [needsResponseFrom] goes false and it simply
      // stops matching this branch).
      final isRequest = chat.needsResponseFrom(myUid);
      if (_filter == _ChatFilter.requests) return isRequest;
      if (isRequest) return false;

      // P0 / H-4 — a conversation this user removed stays out of every
      // filter, including "arxiv" and "oxunmamış". Filtered here rather
      // than in the query because Firestore has no "map value is not
      // true" predicate — the same reason `archivedBy` right below is
      // also an in-memory filter.
      if (chat.isHiddenFor(myUid)) return false;

      final archived = chat.isArchivedFor(myUid);
      if (_filter == _ChatFilter.archived) return archived;
      if (archived) return false;
      if (_filter == _ChatFilter.unread) return chat.unreadFor(myUid) > 0;
      return true;
    }).toList();

    if (_query.isNotEmpty) {
      final q = _azSearchKey(_query);
      result = result.where((chat) {
        final peer = ref.watch(publicProfileProvider(chat.otherParticipant(myUid))).valueOrNull;
        final name = _azSearchKey(peer?.name ?? '');
        final username = _azSearchKey(peer?.username ?? '');
        // `previewFor(myUid)` — a "məndən sil" override shouldn't stay
        // searchable in this uid's own list either (see `_ChatCard`'s
        // identical reasoning for the same call).
        final lastMessage = _azSearchKey(chat.previewFor(myUid).text);
        return name.contains(q) || username.contains(q) || lastMessage.contains(q);
      }).toList();
    }

    result.sort((a, b) {
      // VIP-Faza-3: on Sorğular only, a Premium sender's request jumps
      // ahead of everyone else's — doesn't apply to Hamısı/Oxunmayanlar/
      // Arxivlənənlər, where recency (and pinning) alone still decides
      // order.
      if (_filter == _ChatFilter.requests) {
        final aVip = a.initiatorIsPremium;
        final bVip = b.initiatorIsPremium;
        if (aVip != bVip) return aVip ? -1 : 1;
      }
      final aPinned = a.isPinnedFor(myUid);
      final bPinned = b.isPinnedFor(myUid);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      final aTime = a.lastMessageAt ?? DateTime(0);
      final bTime = b.lastMessageAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    return result;
  }

  /// Splits the already-sorted, already-filtered list into a
  /// "Sabitlənənlər" section (only when at least one pinned chat is
  /// present) followed by "Son söhbətlər" — skipped entirely while
  /// actively searching, since mixing section headers into search
  /// results reads as confusing rather than helpful.
  List<_ChatRow> _buildRows(List<Chat> visible, AppLocalizations loc, String myUid) {
    if (_query.isNotEmpty) {
      return [for (final chat in visible) _ChatRowItem(chat)];
    }

    final pinned = visible.where((c) => c.isPinnedFor(myUid)).toList();
    final rest = visible.where((c) => !c.isPinnedFor(myUid)).toList();

    final rows = <_ChatRow>[];
    if (pinned.isNotEmpty) {
      rows.add(_SectionHeaderRow(loc.chatsPinnedSectionLabel, icon: Icons.push_pin_outlined));
      rows.addAll(pinned.map(_ChatRowItem.new));
    }
    if (rest.isNotEmpty) {
      if (pinned.isNotEmpty) rows.add(_SectionHeaderRow(loc.chatsRecentSectionLabel));
      rows.addAll(rest.map(_ChatRowItem.new));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final listState = ref.watch(chatListControllerProvider);
    final requestsCount =
        myUid == null ? 0 : listState.chats.where((c) => c.needsResponseFrom(myUid)).length;

    return Stack(
      children: [
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Text(
                  loc.chatsTitle,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: _ChatSearchField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              _ChatFilterChips(
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
                requestsCount: requestsCount,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: myUid == null ? const SizedBox.shrink() : _buildBody(loc, myUid, listState),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations loc, String myUid, ChatListState listState) {
    if (listState.isInitialLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (listState.error != null) {
      return FriendlyErrorState(
        logContext: 'chats_tab.chatListControllerProvider',
        error: listState.error!,
        onRetry: () => ref.read(chatListControllerProvider.notifier).retry(),
      );
    }

    final visible = _visibleChats(listState.chats, myUid);
    if (visible.isEmpty) {
      if (_query.isNotEmpty) {
        return _FilterEmptyState(
          icon: Icons.search_off_rounded,
          title: loc.chatsSearchEmptyTitle,
          subtitle: loc.chatsSearchEmptySubtitle,
        );
      }
      return switch (_filter) {
        _ChatFilter.unread => _FilterEmptyState(
            icon: Icons.mark_email_read_outlined,
            title: loc.chatsUnreadEmptyTitle,
            subtitle: loc.chatsUnreadEmptySubtitle,
          ),
        _ChatFilter.archived => _FilterEmptyState(
            icon: Icons.archive_outlined,
            title: loc.chatsArchivedEmptyTitle,
            subtitle: loc.chatsArchivedEmptySubtitle,
          ),
        _ChatFilter.requests => _FilterEmptyState(
            icon: Icons.mark_chat_unread_outlined,
            title: loc.chatsRequestsEmptyTitle,
            subtitle: loc.chatsRequestsEmptySubtitle,
          ),
        _ChatFilter.all => const _EmptyChats(),
      };
    }

    final rows = _buildRows(visible, loc, myUid);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: ListView.builder(
        key: ValueKey(_filter),
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        itemCount: rows.length + (listState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.4)),
            );
          }
          final row = rows[index];
          return switch (row) {
            _SectionHeaderRow() => _SectionHeader(label: row.label, icon: row.icon),
            _ChatRowItem() => _ChatCard(chat: row.chat, myUid: myUid),
          };
        },
      ),
    );
  }
}

class _ChatSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ChatSearchField({required this.controller, required this.onChanged});

  @override
  State<_ChatSearchField> createState() => _ChatSearchFieldState();
}

class _ChatSearchFieldState extends State<_ChatSearchField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: ChatLightColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _focused ? AppColors.primary : Colors.transparent, width: 1.4),
        boxShadow: _focused
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), blurRadius: 12, spreadRadius: 1)]
            : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: loc.chatsSearchHint,
          hintStyle: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14.5),
          prefixIcon: Icon(Icons.search, color: _focused ? AppColors.primary : ChatLightColors.inkFaint, size: 21),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: ChatLightColors.inkFaint, size: 18),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                ),
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _ChatFilterChips extends StatelessWidget {
  final _ChatFilter selected;
  final ValueChanged<_ChatFilter> onSelected;

  /// Count of chats currently awaiting the signed-in user's
  /// accept/decline — shown as a small badge on the Sorğular chip only
  /// (never on the bottom-nav icon; per this app's convention, unread
  /// counts stay inside the page they belong to). Zero hides the badge
  /// entirely rather than showing an empty "0".
  final int requestsCount;

  const _ChatFilterChips({required this.selected, required this.onSelected, required this.requestsCount});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final options = [
      (_ChatFilter.all, loc.chatsFilterAll),
      (_ChatFilter.unread, loc.chatsFilterUnread),
      (_ChatFilter.archived, loc.chatsFilterArchived),
      (_ChatFilter.requests, loc.chatsFilterRequests),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = options[index];
          final isSelected = filter == selected;
          final chip = AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : ChatLightColors.cardSurface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: isSelected
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))]
                  : const [],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : ChatLightColors.inkSoft,
              ),
            ),
          );

          return GestureDetector(
            onTap: () => onSelected(filter),
            child: filter == _ChatFilter.requests && requestsCount > 0
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      chip,
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 17),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ChatLightColors.bg1, width: 1.5),
                          ),
                          child: Text(
                            requestsCount > 99 ? '99+' : '$requestsCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : chip,
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _SectionHeader({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: ChatLightColors.inkSoft),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ChatCard extends ConsumerWidget {
  final Chat chat;
  final String myUid;

  const _ChatCard({required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final otherUid = chat.otherParticipant(myUid);
    final peerAsync = ref.watch(publicProfileProvider(otherUid));
    ref.watch(presenceTickProvider); // forces re-evaluation of isRecentlyActive as time passes
    final peer = peerAsync.valueOrNull;
    final displayName = (peer?.name ?? '').isEmpty ? loc.defaultUserName : peer!.name;
    final unread = chat.unreadFor(myUid);
    final pendingForMe = chat.needsResponseFrom(myUid);
    final pendingFromMe = chat.status == ChatRequestStatus.pending && chat.initiatorId == myUid;
    final isPinned = chat.isPinnedFor(myUid);
    final isMuted = chat.isMutedFor(myUid);
    final isArchived = chat.isArchivedFor(myUid);
    final isUnread = unread > 0;
    const cardRadius = 20.0;

    // `previewFor(myUid)` — NOT `chat.lastMessage`/`chat.lastMessageType`
    // directly — so a "məndən sil" override (this uid's own, if any)
    // takes precedence over the shared fields every other participant
    // sees. See `Chat.previewFor`'s own doc comment.
    final myPreview = chat.previewFor(myUid);
    final preview = switch (myPreview.type) {
      MessageType.image => '📷 ${loc.chatImageMessageLabel}',
      MessageType.video => '🎥 ${loc.chatVideoMessageLabel}',
      MessageType.audio => '🎤 ${loc.chatAudioMessageLabel}',
      MessageType.post => '📎 ${loc.chatPostMessageLabel}',
      MessageType.deleted => loc.chatMessageDeletedPreviewLabel,
      _ => myPreview.text,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Slidable(
        key: ValueKey(chat.id),
        startActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: 0.26,
          children: [
            SlidableAction(
              onPressed: (_) => _togglePin(context, ref, loc, isPinned),
              backgroundColor: isPinned ? ChatLightColors.inkSoft : AppColors.primary,
              foregroundColor: Colors.white,
              icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: isPinned ? loc.chatsUnpinAction : loc.chatsPinAction,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: 0.72,
          // Post-launch QA — was hardcoded to `setArchived(chat.id, true)`,
          // so a full swipe in the Arxivlənənlər tab also archived (a
          // no-op write, already `true`) instead of unarchiving: the row
          // still visually disappeared (Dismissible always removes its
          // widget once dismissed) but the chat silently stayed archived,
          // invisible in Hamısı until the user re-opened Arxivlənənlər and
          // it reappeared there. Toggling off `isArchived` makes dismiss
          // do "remove from the tab you're looking at" in both tabs.
          dismissible: DismissiblePane(
            onDismissed: () => ref.read(chatListControllerProvider.notifier).setArchived(chat.id, !isArchived),
          ),
          children: [
            // Post-launch QA — Səssiz et (mute) revealed FIRST (leftmost).
            // Sil sits in the MIDDLE deliberately: a full swipe always
            // toggles archived state via `dismissible.onDismissed` above
            // (independent of button order), never deletes, so putting
            // Sil at the far edge — where a full swipe visually lands —
            // made it look like the swipe would delete when it actually
            // archived/unarchived. Keeping Arxivlə/Arxivdən çıxar last
            // (next to the dismiss threshold) makes the edge action match
            // what dismissing actually does; Sil in the middle is reachable
            // only by a deliberate partial swipe + tap, never by dismiss.
            SlidableAction(
              onPressed: (_) => ref.read(chatListControllerProvider.notifier).setMuted(chat.id, !isMuted),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              label: isMuted ? loc.chatsUnmuteAction : loc.chatsMuteAction,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            // Post-launch QA — the only way to delete a chat used to be
            // via the other participant's profile-screen menu, which
            // becomes unreachable once their account is deleted (profile
            // stream returns null, header tap disables itself). This
            // button is independent of that entirely. Deliberately NOT
            // wired to `dismissible.onDismissed` above — a full swipe
            // only ever toggles archived state, per explicit decision, so
            // deleting always requires this dedicated button + its
            // confirmation.
            SlidableAction(
              onPressed: (_) => _confirmDeleteChat(context, ref, loc),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: loc.actionDelete,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            SlidableAction(
              onPressed: (_) => ref.read(chatListControllerProvider.notifier).setArchived(chat.id, !isArchived),
              backgroundColor: ChatLightColors.inkSoft,
              foregroundColor: Colors.white,
              icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              label: isArchived ? loc.chatsUnarchiveAction : loc.chatsArchiveAction,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
          ],
        ),
        child: Material(
          color: ChatLightColors.cardSurface,
          borderRadius: BorderRadius.circular(cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatConversationScreen(
                  otherUid: otherUid,
                  otherName: displayName,
                  otherPhotoUrl: peer?.photoUrl,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        backgroundImage: peer?.photoUrl != null ? NetworkImage(peer!.photoUrl!) : null,
                        child: peer?.photoUrl == null
                            ? const Icon(Icons.person_outline, color: ChatLightColors.inkFaint, size: 24)
                            : null,
                      ),
                      if (peer?.isRecentlyActive == true)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ChatLightColors.onlineDot,
                              border: Border.all(color: ChatLightColors.cardSurface, width: 2.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (chat.lastMessageAt != null)
                              Text(
                                _formatTimestamp(loc, chat.lastMessageAt!),
                                style: const TextStyle(fontSize: 11, color: ChatLightColors.inkFaint),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pendingForMe
                                    ? loc.chatRequestBannerTitle
                                    : (pendingFromMe ? loc.chatRequestPendingNotice : preview),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: pendingForMe
                                      ? AppColors.primary
                                      : (isUnread ? ChatLightColors.ink : ChatLightColors.inkFaint),
                                  fontWeight: pendingForMe || isUnread ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isMuted) ...[
                              const Icon(Icons.notifications_off_outlined, size: 14, color: ChatLightColors.inkFaint),
                              const SizedBox(width: 6),
                            ],
                            if (isPinned) ...[
                              const Icon(Icons.push_pin, size: 13, color: ChatLightColors.inkFaint),
                              const SizedBox(width: 6),
                            ],
                            if (isUnread)
                              Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                height: 20,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 5, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Text(
                                  '$unread',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Blocks pinning a 4th chat with a snackbar instead — [chats] (the
  /// full loaded list, not just what's currently visible under a filter/
  /// search) is what the "max 3" count is checked against, so a pin
  /// made while e.g. the Arxivlənənlər filter is active still counts
  /// correctly.
  void _togglePin(BuildContext context, WidgetRef ref, AppLocalizations loc, bool isPinned) {
    if (!isPinned) {
      final pinnedCount = ref.read(chatListControllerProvider).chats.where((c) => c.isPinnedFor(myUid)).length;
      if (pinnedCount >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatsPinLimitReachedMessage)));
        return;
      }
    }
    ref.read(chatListControllerProvider.notifier).setPinned(chat.id, !isPinned);
  }

  Future<void> _confirmDeleteChat(BuildContext context, WidgetRef ref, AppLocalizations loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.chatDeleteConfirmTitle),
        content: Text(loc.chatDeleteConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(chatControllerProvider.notifier).deleteChat(chat.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatDeletedNotice)));
    } catch (e, st) {
      logError('chats_tab.deleteChat', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatRequestActionErrorMessage)));
    }
  }

  String _formatTimestamp(AppLocalizations loc, DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return DateFormat('HH:mm').format(dateTime);
    if (diff == 1) return loc.chatDateYesterday;
    return DateFormat('dd.MM').format(dateTime);
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return _FilterEmptyState(
      icon: Icons.chat_bubble_outline,
      title: loc.chatsEmptyTitle,
      subtitle: loc.chatsEmptySubtitle,
    );
  }
}

/// Shared premium empty-state layout for "Hamısı" (no chats at all),
/// the two filter tabs (no unread / nothing archived), and an active
/// search that matched nothing — same shell, different icon/copy.
class _FilterEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FilterEmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: ChatLightColors.cardSurface),
              child: Icon(icon, color: ChatLightColors.inkFaint, size: 38),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: ChatLightColors.inkFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
