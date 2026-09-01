import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../app_config/domain/entities/app_config.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/private_data_ref.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/friendly_error_state.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/app_localizations.dart';
import '../theme/chat_light_theme.dart';
import '../../../calls/domain/entities/call_session.dart';
import '../../../calls/presentation/providers/active_call_controller.dart';
import '../../../calls/presentation/providers/call_providers.dart';
import '../../../calls/presentation/screens/call_screen.dart';
import '../../../location/presentation/providers/presence_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../../profile/presentation/widgets/verification_badges.dart';
import '../../../post_share/presentation/screens/post_detail_screen.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../../domain/chat_failure.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_providers.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/fullscreen_media_viewer.dart';
import '../widgets/post_message_bubble.dart';
import '../widgets/video_message_bubble.dart';
import 'forward_message_screen.dart';
import 'media_send_preview_screen.dart';

/// 8pt grid used throughout this screen's layout.
class _Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Replaces the native `AppBar` — a translucent, blurred bar floating
/// over the same continuous background (rather than a solid opaque
/// strip), so the contour/glow effect reads as one unbroken surface
/// behind it. A bigger avatar and bolder name than before, per spec.
class _ChatHeader extends StatelessWidget {
  final String peerName;
  final String? peerUsername;
  final String? peerPhoto;
  final String statusText;
  final bool statusIsLive;
  final VoidCallback onBack;

  /// Null when the peer's profile is unreachable — blocked (Düzəliş
  /// Prompt 5 / K-3) or deleted — same "İstifadəçi" + grey avatar
  /// fallback [peerName]/[peerPhoto] already show; a null callback
  /// disables the tap gesture instead of pushing a "Hesab tapılmadı"
  /// screen for a name the user can already see right here.
  final VoidCallback? onTapProfile;
  final VoidCallback onCall;
  final VoidCallback onVideoCall;
  final String callLabel;
  final String videoCallLabel;

  /// False while the message request between these two hasn't been
  /// accepted yet — calling a stranger before they've even accepted
  /// your message request shouldn't be possible. Disabling the button
  /// here (rather than just letting `_startCall` reject it) also keeps
  /// it visibly greyed out and untappable, matching how `_Composer` is
  /// already swapped out for `_PendingNotice`/`_RequestBanner` in the
  /// same pending state.
  /// Whether the call buttons EXIST at all (`FeatureFlag.calls`).
  ///
  /// Separate from [callsEnabled] on purpose. A greyed-out button still
  /// advertises a feature and invites a tap that explains nothing;
  /// while calling is hidden for launch the buttons must not be drawn.
  /// [callsEnabled] keeps its original meaning — the feature exists but
  /// this particular chat has not been accepted yet — and still shows
  /// the disabled state with its explanatory tooltip.
  final bool callsVisible;
  final bool callsEnabled;
  final String callsDisabledTooltip;
  final bool peerIdentityVerified;
  final bool peerPremium;

  /// Independent of [onTapProfile]/the peer's profile stream — deleting
  /// the chat must stay reachable even when the peer's `users/{uid}` doc
  /// is gone (profile screen unreachable, see [onTapProfile]'s doc
  /// comment), since that used to be the ONLY place this action lived.
  final VoidCallback onDeleteChat;

  const _ChatHeader({
    required this.peerName,
    required this.peerUsername,
    required this.peerPhoto,
    required this.statusText,
    required this.statusIsLive,
    required this.onBack,
    required this.onTapProfile,
    required this.onCall,
    required this.onVideoCall,
    required this.callLabel,
    required this.videoCallLabel,
    required this.callsVisible,
    required this.callsEnabled,
    required this.callsDisabledTooltip,
    required this.peerIdentityVerified,
    required this.peerPremium,
    required this.onDeleteChat,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: ChatLightColors.barTint.withValues(alpha: 0.72),
            border: const Border(
              bottom: BorderSide(color: Colors.black12, width: 0.6),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 10, _Spacing.sm, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: ChatLightColors.ink,
                ),
              ),
              Expanded(
                child: Pressable(
                  onTap: onTapProfile,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor: Colors.white,
                        backgroundImage: peerPhoto != null
                            ? NetworkImage(peerPhoto!)
                            : null,
                        child: peerPhoto == null
                            ? const Icon(
                                Icons.person_outline,
                                color: ChatLightColors.inkFaint,
                                size: 22,
                              )
                            : null,
                      ),
                      const SizedBox(width: _Spacing.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    peerName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.1,
                                      color: ChatLightColors.ink,
                                    ),
                                  ),
                                ),
                                if (peerIdentityVerified || peerPremium) ...[
                                  const SizedBox(width: 4),
                                  VerificationBadges(
                                    identityVerified: peerIdentityVerified,
                                    premium: peerPremium,
                                    size: 15,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 1),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (statusIsLive) ...[
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ChatLightColors.onlineDot,
                                    ),
                                  ),
                                ],
                                Flexible(
                                  child: MarqueeText(
                                    peerUsername != null &&
                                            peerUsername!.isNotEmpty
                                        ? '@$peerUsername · $statusText'
                                        : statusText,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w400,
                                      color: statusIsLive
                                          ? ChatLightColors.onlineGreen
                                          : ChatLightColors.inkFaint,
                                    ),
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
              if (callsVisible) ...[
                IconButton(
                  onPressed: callsEnabled ? onCall : null,
                  tooltip: callsEnabled ? callLabel : callsDisabledTooltip,
                  icon: Icon(
                    Icons.call_outlined,
                    color: callsEnabled
                        ? ChatLightColors.inkSoft
                        : ChatLightColors.inkFaint,
                    size: 21,
                  ),
                ),
                IconButton(
                  onPressed: callsEnabled ? onVideoCall : null,
                  tooltip: callsEnabled ? videoCallLabel : callsDisabledTooltip,
                  icon: Icon(
                    Icons.videocam_outlined,
                    color: callsEnabled
                        ? ChatLightColors.inkSoft
                        : ChatLightColors.inkFaint,
                    size: 23,
                  ),
                ),
              ],
              PopupMenuButton<void>(
                icon: const Icon(
                  Icons.more_vert,
                  color: ChatLightColors.inkSoft,
                  size: 21,
                ),
                onSelected: (_) => onDeleteChat(),
                itemBuilder: (menuContext) => [
                  PopupMenuItem<void>(
                    value: null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(menuContext).actionDelete,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _chatFailureMessage(AppLocalizations loc, ChatFailure type) {
  switch (type) {
    case ChatFailure.requestDeclined:
      return loc.chatRequestDeclinedNotice;
    case ChatFailure.blocked:
      return loc.chatSendBlockedError;
    case ChatFailure.requestPending:
      return loc.chatRequestPendingNotice;
    case ChatFailure.notAllowedByRecipient:
      return loc.chatSendNotAllowedByRecipientError;
  }
}

/// A single row in the flattened, scrollable thread — either a real
/// message, a still-uploading one, or a date capsule inserted between
/// them. Built once per [messagesAsync]/[pendingMessages] change (see
/// `_buildThreadItems`), not sticky — it scrolls with everything else,
/// exactly like a normal bubble.
sealed class _ThreadItem {
  const _ThreadItem();
}

class _DateSeparatorItem extends _ThreadItem {
  final DateTime day;
  const _DateSeparatorItem(this.day);
}

class _MessageItem extends _ThreadItem {
  final ChatMessage message;
  final bool tightGap;
  const _MessageItem(this.message, this.tightGap);
}

class _PendingItem extends _ThreadItem {
  final PendingOutgoingMessage message;
  final bool tightGap;
  const _PendingItem(this.message, this.tightGap);
}

/// A message is grouped "tight" with the one before it (8-12px gap)
/// when it's the same sender, same calendar day, and close enough in
/// time (<5min) to read as one burst — same-sender messages minutes or
/// hours apart still get the wider (16-20px) gap, since a burst is
/// about pacing, not just identity.
const _kGroupingWindow = Duration(minutes: 5);

List<_ThreadItem> _buildThreadItems({
  required List<ChatMessage> messages,
  required List<PendingOutgoingMessage> pending,
  required String myUid,
}) {
  final items = <_ThreadItem>[];
  DateTime? lastDay;
  String? lastSenderId;
  DateTime? lastAt;

  for (final message in messages) {
    final day = DateTime(
      message.sentAt.year,
      message.sentAt.month,
      message.sentAt.day,
    );
    final isNewDay = lastDay == null || day != lastDay;
    if (isNewDay) {
      items.add(_DateSeparatorItem(day));
    }
    final tight =
        !isNewDay &&
        lastSenderId == message.senderId &&
        lastAt != null &&
        message.sentAt.difference(lastAt).abs() < _kGroupingWindow;
    items.add(_MessageItem(message, tight));
    lastDay = day;
    lastSenderId = message.senderId;
    lastAt = message.sentAt;
  }

  // Pending uploads are always mine and always trail the real list, so
  // they only ever need the sender check (day/time bursts don't apply
  // to something still uploading).
  for (final message in pending) {
    items.add(_PendingItem(message, lastSenderId == myUid));
    lastSenderId = myUid;
  }

  return items;
}

const _azMonths = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avqust',
  'sentyabr',
  'oktyabr',
  'noyabr',
  'dekabr',
];

/// "Bugün"/"Dünən" for the two closest days, otherwise "18 iyul" (or
/// "18 iyul 2025" once it's a different year) — written out manually
/// rather than via `DateFormat`'s locale tables, since this app's `az`
/// locale isn't registered with `intl`'s date-symbol data.
String _formatDateSeparator(AppLocalizations loc, DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return loc.chatDateToday;
  if (diff == 1) return loc.chatDateYesterday;

  final month = _azMonths[day.month - 1];
  return day.year == now.year
      ? '${day.day} $month'
      : '${day.day} $month ${day.year}';
}

/// A normal (non-sticky) scrolling capsule — shown once per day change,
/// never repeated for consecutive messages on the same day.
class _DateSeparator extends StatelessWidget {
  final DateTime day;

  const _DateSeparator({required this.day});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _Spacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _formatDateSeparator(loc, day),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ChatLightColors.inkSoft,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String otherUid;
  final String otherName;
  final String? otherPhotoUrl;

  const ChatConversationScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
    this.otherPhotoUrl,
  });

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  Timer? _markSeenDebounce;
  bool _isTyping = false;
  bool _sending = false;
  bool _isForeground = true;
  String? _myUid;
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    _myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    _chatId = chatIdWith(widget.otherUid);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestMarkSeen());
    _setActiveChatId(_chatId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _markSeenDebounce?.cancel();
    if (_isTyping) {
      ref.read(chatControllerProvider.notifier).setTyping(_chatId, false);
    }
    _setActiveChatId(null);
    _textController.dispose();
    _textFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _requestMarkSeen();
      _setActiveChatId(_chatId);
    } else {
      _setActiveChatId(null);
    }
  }

  /// Server-visible "am I looking at this chat right now" flag —
  /// `onChatMessageCreated` (Cloud Function) reads `users/{uid}/private/
  /// data.activeChatId` (Düzəliş Prompt 4) to skip a push for a chat the
  /// recipient already has open, so an incoming message doesn't also
  /// buzz their phone. Purely best-effort like the rest of this
  /// screen's presence bookkeeping (`_isForeground`) — a lost race just
  /// means one push shows or gets skipped when it ideally wouldn't,
  /// never a correctness issue.
  void _setActiveChatId(String? chatId) {
    final uid = _myUid;
    if (uid == null) return;
    unawaited(privateDataRef(uid).update({'activeChatId': chatId}));
  }

  /// Debounced so a screen that's opened and immediately swiped back
  /// away (before the delay fires) never counts as "genuinely viewed" —
  /// per the bug report, sending alone (or an instant open-then-close)
  /// must never auto-mark as read. Also skipped entirely while
  /// backgrounded (`_isForeground`), so a Firestore snapshot arriving
  /// to an already-mounted-but-backgrounded screen doesn't silently
  /// mark it read either — that was the actual repro for the "offline
  /// recipient shows read instantly" bug: this screen staying mounted
  /// in the background while `ref.listen` kept firing on new messages.
  void _requestMarkSeen() {
    _markSeenDebounce?.cancel();
    _markSeenDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _isForeground) _markSeen();
    });
  }

  void _markSeen() {
    final controller = ref.read(chatControllerProvider.notifier);
    controller.markDelivered(_chatId);
    controller.markRead(_chatId);
  }

  void _onTextChanged(String value) {
    final typingNow = value.trim().isNotEmpty;
    if (typingNow != _isTyping) {
      _isTyping = typingNow;
      ref.read(chatControllerProvider.notifier).setTyping(_chatId, typingNow);
    }
    _typingTimer?.cancel();
    if (typingNow) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isTyping = false;
        ref.read(chatControllerProvider.notifier).setTyping(_chatId, false);
      });
    }
    // Rebuilds the composer so its trailing button can swap mic <-> send.
    setState(() {});
  }

  void _fillGreeting() {
    final loc = AppLocalizations.of(context);
    final greeting = loc.chatEmptyStateGreetingButton;
    _textController.value = TextEditingValue(
      text: greeting,
      selection: TextSelection.collapsed(offset: greeting.length),
    );
    _onTextChanged(greeting);
    _textFocusNode.requestFocus();
  }

  Future<void> _send(Chat? chat) async {
    final text = _textController.text;
    if (text.trim().isEmpty || _sending) return;
    if (!mounted) return;

    final loc = AppLocalizations.of(context);
    final wasOpeningMessage =
        chat == null ||
        (chat.status == ChatRequestStatus.pending &&
            chat.lastMessageSenderId == null);

    setState(() => _sending = true);
    _textController.clear();
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      unawaited(
        ref.read(chatControllerProvider.notifier).setTyping(_chatId, false),
      );
    }

    try {
      await ref
          .read(chatControllerProvider.notifier)
          .sendText(otherUid: widget.otherUid, text: text);
      if (!mounted) return;
      if (wasOpeningMessage) {
        _showToast(
          icon: Icons.mark_email_read_outlined,
          message: loc.chatRequestSentNotice,
        );
      } else {
        _scrollToBottom();
      }
    } on ChatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatFailureMessage(loc, e.type))));
    } catch (e, st) {
      logError('chat_conversation_screen.sendText', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.chatRequestActionErrorMessage)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showToast({required IconData icon, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider, width: 1.2),
        ),
        content: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: _Spacing.sm + 4),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCall({required bool video}) async {
    if (!mounted) return;

    final loc = AppLocalizations.of(context);
    // Defense in depth: the call buttons are already disabled in
    // `_ChatHeader` while the message request isn't accepted, but this
    // guards the one real code path that starts a call regardless of
    // which UI trigger reaches it.
    final chat = ref.read(chatByIdProvider(_chatId)).valueOrNull;
    if (chat?.status != ChatRequestStatus.accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.chatCallDisabledTooltip)));
      return;
    }
    // Defence in depth: the buttons are hidden while the feature is
    // off, but this method is also reachable from anywhere else that
    // might call it in future, and the check costs nothing.
    if (!ref.read(featureFlagProvider(FeatureFlag.calls))) return;

    final type = video ? CallType.video : CallType.audio;
    try {
      final session = await ref
          .read(callRepositoryProvider)
          .startCall(receiverId: widget.otherUid, type: type);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: session.id,
            otherUid: widget.otherUid,
            type: type,
            isCaller: true,
          ),
        ),
      );
    } catch (e, st) {
      logError('chat_conversation_screen._startCall', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.callStartFailedMessage)));
    }
  }

  /// Mirrors `UserProfileScreen._confirmDeleteChat` — same confirm dialog,
  /// same `deleteChat` call, same post-delete navigation — but reachable
  /// from `_ChatHeader`'s own menu regardless of whether the peer's
  /// profile stream ever resolves, since that was the only route before.
  Future<void> _confirmDeleteChat(
    BuildContext context,
    AppLocalizations loc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.chatDeleteConfirmTitle),
        content: Text(loc.chatDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(chatControllerProvider.notifier).deleteChat(_chatId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.chatDeletedNotice)));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e, st) {
      logError('chat_conversation_screen._confirmDeleteChat', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.chatRequestActionErrorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final myUid = _myUid;
    final chatAsync = ref.watch(chatByIdProvider(_chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(_chatId));
    final peerAsync = ref.watch(publicProfileProvider(widget.otherUid));
    final pendingMessages = ref.watch(pendingMessagesForChatProvider(_chatId));

    ref.listen(chatMessagesProvider(_chatId), (previous, next) {
      final prevLen = previous?.valueOrNull?.length ?? 0;
      final nextLen = next.valueOrNull?.length ?? 0;
      if (nextLen > prevLen) {
        _requestMarkSeen();
        _scrollToBottom();
      }
    });

    ref.listen(chatByIdProvider(_chatId), (previous, next) {
      next.whenOrNull(
        error: (e, st) =>
            logError('chat_conversation_screen.chatByIdProvider', e, st),
      );
    });

    ref.listen(pendingMessagesForChatProvider(_chatId), (previous, next) {
      if (next.length > (previous?.length ?? 0)) _scrollToBottom();
    });

    if (myUid == null) return const SizedBox.shrink();

    final chat = chatAsync.valueOrNull;
    final peer = peerAsync.valueOrNull;
    final peerName = (peer?.name ?? widget.otherName).isEmpty
        ? loc.defaultUserName
        : (peer?.name ?? widget.otherName);
    final peerPhoto = peer?.photoUrl ?? widget.otherPhotoUrl;
    final myPhoto = ref.watch(profileControllerProvider).photoUrl;
    final isPeerTyping = chat?.typingUserId == widget.otherUid;
    ref.watch(
      presenceTickProvider,
    ); // forces re-evaluation of isRecentlyActive as time passes
    final isPeerOnline = peer?.isRecentlyActive == true;
    final peerLastSeen = peer?.lastSeen;
    final statusText = isPeerTyping
        ? loc.chatTypingIndicator
        : (isPeerOnline
              ? loc.chatOnlineStatus
              : (peerLastSeen != null
                    ? loc.chatLastSeenAt(formatLastSeen(peerLastSeen, loc))
                    : loc.chatLastSeenUnknown));
    final statusIsLive = isPeerTyping || isPeerOnline;
    final canCompose =
        !(chat != null &&
            (chat.needsResponseFrom(myUid) ||
                (chat.status == ChatRequestStatus.pending &&
                    chat.initiatorId == myUid) ||
                chat.status == ChatRequestStatus.declined));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _ChatHeader(
                  peerName: peerName,
                  peerUsername: peer?.username,
                  peerPhoto: peerPhoto,
                  statusText: statusText,
                  statusIsLive: statusIsLive,
                  peerIdentityVerified: peer?.identityVerified ?? false,
                  peerPremium: peer?.premium ?? false,
                  onBack: () => Navigator.pop(context),
                  onTapProfile: peer == null
                      ? null
                      : () {
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                uid: widget.otherUid,
                                initialName: peerName,
                                initialPhotoUrl: peerPhoto,
                                chatId: _chatId,
                              ),
                            ),
                          );
                        },
                  onCall: () => _startCall(video: false),
                  onVideoCall: () => _startCall(video: true),
                  callLabel: loc.chatVoiceCallLabel,
                  videoCallLabel: loc.chatVideoCallLabel,
                  callsVisible: ref.watch(
                    featureFlagProvider(FeatureFlag.calls),
                  ),
                  callsEnabled: chat?.status == ChatRequestStatus.accepted,
                  callsDisabledTooltip: loc.chatCallDisabledTooltip,
                  onDeleteChat: () => _confirmDeleteChat(context, loc),
                ),
                _OngoingCallBanner(otherUid: widget.otherUid),
                Expanded(
                  child: messagesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    error: (e, st) => FriendlyErrorState(
                      logContext:
                          'chat_conversation_screen.chatMessagesProvider',
                      error: e,
                      stackTrace: st,
                      onRetry: () =>
                          ref.invalidate(chatMessagesProvider(_chatId)),
                    ),
                    data: (messages) {
                      if (messages.isEmpty && pendingMessages.isEmpty) {
                        return _EmptyConversationState(
                          loc: loc,
                          onGreet: _fillGreeting,
                        );
                      }
                      final items = _buildThreadItems(
                        messages: messages,
                        pending: pendingMessages,
                        myUid: myUid,
                      );
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          _Spacing.md,
                          _Spacing.md,
                          _Spacing.md,
                          _Spacing.sm,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return switch (item) {
                            _DateSeparatorItem() => _DateSeparator(
                              day: item.day,
                            ),
                            _MessageItem() => _MessageBubble(
                              key: ValueKey('msg_${item.message.id}'),
                              chatId: _chatId,
                              message: item.message,
                              isMine: item.message.senderId == myUid,
                              avatarUrl: item.message.senderId == myUid
                                  ? myPhoto
                                  : peerPhoto,
                              myUid: myUid,
                              topGap: item.tightGap ? _Spacing.sm : 18,
                            ),
                            _PendingItem() => _PendingMessageBubble(
                              key: ValueKey('pending_${item.message.localId}'),
                              message: item.message,
                              topGap: item.tightGap ? _Spacing.sm : 18,
                              onRetry: () => ref
                                  .read(pendingMessagesProvider.notifier)
                                  .retry(
                                    chatId: _chatId,
                                    otherUid: widget.otherUid,
                                    message: item.message,
                                  ),
                              onDismiss: () => ref
                                  .read(pendingMessagesProvider.notifier)
                                  .dismiss(_chatId, item.message.localId),
                            ),
                          };
                        },
                      );
                    },
                  ),
                ),
                if (chat != null && chat.needsResponseFrom(myUid))
                  _RequestBanner(chatId: _chatId)
                else if (chat != null &&
                    chat.status == ChatRequestStatus.pending &&
                    chat.initiatorId == myUid)
                  _PendingNotice(loc: loc)
                else if (chat != null &&
                    chat.status == ChatRequestStatus.declined)
                  _DeclinedNotice(
                    loc: loc,
                    iAmInitiator: chat.initiatorId == myUid,
                  )
                else if (canCompose)
                  _Composer(
                    chatId: _chatId,
                    otherUid: widget.otherUid,
                    controller: _textController,
                    focusNode: _textFocusNode,
                    sending: _sending,
                    onChanged: _onTextChanged,
                    onSend: () => _send(chat),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium empty-conversation state — icon, title/subtitle pair, and a
/// one-tap greeting button that drafts (but does not auto-send) an
/// opening message.
class _EmptyConversationState extends StatelessWidget {
  final AppLocalizations loc;
  final VoidCallback onGreet;

  const _EmptyConversationState({required this.loc, required this.onGreet});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: ChatLightColors.inkFaint,
                size: 30,
              ),
            ),
            const SizedBox(height: _Spacing.md),
            Text(
              loc.chatEmptyStateTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ChatLightColors.ink,
              ),
            ),
            const SizedBox(height: _Spacing.xs),
            Text(
              loc.chatEmptyStateSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: ChatLightColors.inkFaint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: _Spacing.lg),
            ElevatedButton(
              onPressed: onGreet,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 48),
                padding: const EdgeInsets.symmetric(horizontal: _Spacing.lg),
              ),
              child: Text(loc.chatEmptyStateGreetingButton),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MessageMenuAction { deleteForMe, deleteForEveryone, forward }

/// Sticky "Zəng davam edir · 02:14" strip under the header — only ever
/// visible while there's a minimized call with *this* chat's other
/// participant (a full-screen [CallScreen] covers this screen entirely
/// while not minimized, so there's no case where a call is active,
/// isn't minimized, and this conversation screen is still on-view).
/// Tapping it un-minimizes back to the full-screen call UI.
class _OngoingCallBanner extends ConsumerWidget {
  final String otherUid;

  const _OngoingCallBanner({required this.otherUid});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(activeCallControllerProvider);
    if (!call.hasActiveCall || !call.minimized || call.otherUid != otherUid) {
      return const SizedBox.shrink();
    }
    final loc = AppLocalizations.of(context);

    return Pressable(
      onTap: () {
        ref.read(activeCallControllerProvider.notifier).restore();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: call.callId!,
              otherUid: call.otherUid!,
              type: call.type!,
              isCaller: call.isCaller,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.primary.withValues(alpha: 0.12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              loc.chatCallOngoingBannerLabel(_formatDuration(call.duration)),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final String chatId;
  final ChatMessage message;
  final bool isMine;
  final String? avatarUrl;
  final String myUid;

  /// 8-12px for a same-sender burst, 16-20px otherwise — computed once
  /// per item by `_buildThreadItems`, not by this widget.
  final double topGap;

  const _MessageBubble({
    super.key,
    required this.chatId,
    required this.message,
    required this.isMine,
    this.avatarUrl,
    required this.myUid,
    required this.topGap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Call-log entries are a centered system-style pill, not a
    // left/right sender bubble — bail out before any of the bubble
    // chrome below.
    if (message.isCall) {
      return _CallLogRow(message: message, myUid: myUid, topGap: topGap);
    }

    // Differentiated by a cyan-tinted gradient (mine) vs plain white
    // (theirs), matching the approved premium-light mockup — the old
    // dark-theme version differentiated by shade alone.
    const textColor = ChatLightColors.ink;
    final isMedia = message.isImage || message.isVideo || message.isPost;

    return GestureDetector(
          onLongPress: () => _openMessageMenu(context, ref),
          child: Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              margin: EdgeInsets.only(top: topGap),
              padding: isMedia
                  ? const EdgeInsets.all(_Spacing.xs)
                  : const EdgeInsets.symmetric(
                      horizontal: _Spacing.md,
                      vertical: _Spacing.sm + 2,
                    ),
              decoration: BoxDecoration(
                color: isMine ? null : ChatLightColors.bubbleTheirs,
                gradient: isMine
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ChatLightColors.bubbleMineStart, Colors.white],
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isMine ? 22 : 6),
                  bottomRight: Radius.circular(isMine ? 6 : 22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMine
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : const Color(0x0F3C4650),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildContent(context, ref, textColor),
                  const SizedBox(height: 3),
                  Padding(
                    padding: isMedia
                        ? const EdgeInsets.only(
                            right: _Spacing.xs + 2,
                            bottom: 2,
                          )
                        : EdgeInsets.zero,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(message.sentAt),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isMedia
                                ? Colors.white70
                                : ChatLightColors.inkFaint,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: _Spacing.xs),
                          Builder(
                            builder: (context) {
                              // "Mesaj oxundu məlumatını göstər" is bidirectional
                              // (WhatsApp's own rule, see PrivacySettings.showReadReceipts'
                              // doc comment): turning it off also hides read receipts
                              // FROM this user, even on their own sent messages, even
                              // though the recipient genuinely did read it.
                              final myShowReadReceipts =
                                  ref
                                      .watch(privacySettingsProvider)
                                      .valueOrNull
                                      ?.showReadReceipts ??
                                  true;
                              final isRead =
                                  myShowReadReceipts &&
                                  message.deliveryStatus ==
                                      MessageDeliveryStatus.read;
                              final isDelivered =
                                  isRead ||
                                  message.deliveryStatus !=
                                      MessageDeliveryStatus.sent;
                              return Icon(
                                isDelivered ? Icons.done_all : Icons.done,
                                size: 14,
                                color: isRead
                                    ? AppColors.primary
                                    : (isMedia
                                          ? Colors.white70
                                          : ChatLightColors.inkFaint),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(key: ValueKey('anim_${message.id}'))
        .fadeIn(duration: 220.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 220.ms, curve: Curves.easeOut);
  }

  Future<void> _openMessageMenu(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_MessageMenuAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (isMine) ...[
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: ChatLightColors.ink,
                ),
                title: Text(
                  loc.chatMessageDeleteForMeOption,
                  style: const TextStyle(fontSize: 15),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _MessageMenuAction.deleteForMe),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: AppColors.error,
                ),
                title: Text(
                  loc.chatMessageDeleteForEveryoneOption,
                  style: const TextStyle(fontSize: 15, color: AppColors.error),
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _MessageMenuAction.deleteForEveryone,
                ),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: ChatLightColors.ink,
                ),
                title: Text(
                  loc.chatMessageDeleteOption,
                  style: const TextStyle(fontSize: 15),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _MessageMenuAction.deleteForMe),
              ),
              ListTile(
                leading: const Icon(
                  Icons.forward_outlined,
                  color: ChatLightColors.ink,
                ),
                title: Text(
                  loc.chatMessageForwardOption,
                  style: const TextStyle(fontSize: 15),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _MessageMenuAction.forward),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _MessageMenuAction.deleteForMe:
        // Bonus post-launch QA finding — the returned bool used to be
        // silently dropped, so a failed delete (rules rejection, offline,
        // anything) looked identical to a successful one: no error, the
        // message just stayed put with no explanation why.
        final deletedForMe = await ref
            .read(chatControllerProvider.notifier)
            .deleteMessageForMe(chatId: chatId, messageId: message.id);
        if (!deletedForMe && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.chatMessageDeleteFailedError)),
          );
        }
      case _MessageMenuAction.deleteForEveryone:
        final confirmed = await _confirmDeleteForEveryone(context, loc);
        if (confirmed != true || !context.mounted) return;
        final deletedForEveryone = await ref
            .read(chatControllerProvider.notifier)
            .deleteMessageForEveryone(chatId: chatId, messageId: message.id);
        if (!deletedForEveryone && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.chatMessageDeleteFailedError)),
          );
        }
      case _MessageMenuAction.forward:
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ForwardMessageScreen(message: message),
          ),
        );
    }
  }

  Future<bool?> _confirmDeleteForEveryone(
    BuildContext context,
    AppLocalizations loc,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.chatMessageDeleteForEveryoneOption),
        content: Text(loc.chatMessageDeleteForEveryoneConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.actionDelete),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Color textColor) {
    if (message.isImage && message.mediaUrl != null) {
      return Pressable(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullscreenMediaViewer(
              mediaUrl: message.mediaUrl!,
              type: MessageType.image,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AppImage(
            message.mediaUrl!,
            fit: BoxFit.cover,
            width: 220,
            height: 220,
            errorBuilder: (_, _, _) => Container(
              width: 220,
              height: 220,
              color: ChatLightColors.composerFill,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: ChatLightColors.inkFaint,
              ),
            ),
          ),
        ),
      );
    }
    if (message.isVideo && message.mediaUrl != null) {
      return VideoMessageBubble(videoUrl: message.mediaUrl!);
    }
    if (message.isPost && message.postId != null) {
      return PostMessageBubble(
        postId: message.postId!,
        thumbnailUrl: message.mediaUrl,
        isVideo: message.postIsVideo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: message.postId!),
          ),
        ),
      );
    }
    if (message.isAudio && message.mediaUrl != null) {
      return AudioMessagePlayer(
        audioUrl: message.mediaUrl!,
        durationMs: message.durationMs,
        accentColor: AppColors.primary,
        trackColor: ChatLightColors.composerFill,
        labelColor: ChatLightColors.inkFaint,
        avatarUrl: avatarUrl,
        onPlayStarted: isMine
            ? null
            : () => ref
                  .read(chatControllerProvider.notifier)
                  .markMessageRead(chatId, message.id),
      );
    }
    return Text(
      message.text ?? '',
      style: AppTextStyles.body.copyWith(color: textColor, fontSize: 15),
    );
  }
}

/// WhatsApp-style call-log entry — a centered system pill rather than
/// a left/right sender bubble, since a call is something that happened
/// *to the conversation*, not a message either side "sent". Wording
/// and arrow direction depend on [ChatMessage.callerId] vs [myUid],
/// not on who happened to write the log doc (see `logCallMessage`'s
/// doc comment) — "Cavab verilmədi" only makes sense from the caller's
/// own side.
class _CallLogRow extends StatelessWidget {
  final ChatMessage message;
  final String myUid;
  final double topGap;

  const _CallLogRow({
    required this.message,
    required this.myUid,
    required this.topGap,
  });

  String _formatDuration(AppLocalizations loc, int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes <= 0) return loc.chatCallDurationSecOnly(seconds);
    return loc.chatCallDurationMinSec(minutes, seconds);
  }

  String _formatDataUsage(int bytes) {
    const mb = 1024 * 1024;
    const gb = 1024 * mb;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final iAmCaller = message.callerId == myUid;
    final isVideo = message.callMessageType == CallMessageType.video;
    final missed = message.callOutcome == CallMessageOutcome.missed;

    final Color tint = missed ? AppColors.error : const Color(0xFF16A34A);
    final IconData icon = missed
        ? (iAmCaller ? Icons.call_missed_outgoing : Icons.call_missed)
        : (isVideo ? Icons.videocam_outlined : Icons.call_outlined);

    final String label = missed
        ? (iAmCaller
              ? loc.chatCallNoAnswerLabel
              : (isVideo
                    ? loc.chatCallMissedVideoLabel
                    : loc.chatCallMissedVoiceLabel))
        : (isVideo
              ? loc.chatCallCompletedVideoLabel
              : loc.chatCallCompletedVoiceLabel);

    final durationSeconds = message.callDurationSeconds;
    final dataUsage = message.callDataUsageBytes;

    return Center(
      child: Container(
        margin: EdgeInsets.only(top: topGap),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: tint),
                const SizedBox(width: 6),
                Text(
                  !missed && durationSeconds != null
                      ? '$label · ${_formatDuration(loc, durationSeconds)}'
                      : label,
                  style: AppTextStyles.caption.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('HH:mm').format(message.sentAt),
                  style: AppTextStyles.caption.copyWith(
                    color: ChatLightColors.inkFaint,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            if (!missed && dataUsage != null) ...[
              const SizedBox(height: 2),
              Text(
                loc.chatCallDataUsageLabel(_formatDataUsage(dataUsage)),
                style: AppTextStyles.caption.copyWith(
                  color: ChatLightColors.inkFaint,
                  fontSize: 10.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders a media send that's still uploading (or failed) — the
/// optimistic overlay described in [PendingOutgoingMessage].
class _PendingMessageBubble extends StatelessWidget {
  final PendingOutgoingMessage message;
  final double topGap;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _PendingMessageBubble({
    super.key,
    required this.message,
    required this.topGap,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final failed = message.status == PendingMessageStatus.failed;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(top: topGap),
        padding: const EdgeInsets.all(_Spacing.xs),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ChatLightColors.bubbleMineStart, Colors.white],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x243C4650),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 180,
                height: message.type == MessageType.audio ? 56 : 180,
                child: message.type == MessageType.image
                    ? Opacity(
                        opacity: failed ? 0.5 : 1,
                        child: Image.file(message.file, fit: BoxFit.cover),
                      )
                    : Container(
                        color: ChatLightColors.composerFill,
                        alignment: Alignment.center,
                        child: Icon(
                          message.type == MessageType.video
                              ? Icons.videocam_outlined
                              : Icons.mic_none_outlined,
                          color: ChatLightColors.inkFaint,
                          size: 32,
                        ),
                      ),
              ),
            ),
            if (!failed)
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: message.progress > 0 ? message.progress : null,
                  strokeWidth: 2.6,
                  // Literal white, not the AppColors.white token — this
                  // spinner sits directly on a photo/video thumbnail
                  // (see Colors.black26 track below), not on app chrome,
                  // so it stays theme-independent like the other
                  // media-overlay colors.
                  color: Colors.white,
                  backgroundColor: Colors.black26,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.chatMediaUploadFailedMessage,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Text-only actions on a failed message. Bare
                        // text with no feedback reads as a label, not a
                        // button — the padding also gives a finger
                        // something to hit.
                        Pressable(
                          onTap: onRetry,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              loc.actionRetry,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Pressable(
                          onTap: onDismiss,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              loc.actionDelete,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.error,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
    );
  }
}

/// The recipient's Accept/Decline prompt for a pending message request.
class _RequestBanner extends ConsumerStatefulWidget {
  final String chatId;

  const _RequestBanner({required this.chatId});

  @override
  ConsumerState<_RequestBanner> createState() => _RequestBannerState();
}

enum _RequestBannerAction { none, accepting, declining }

class _RequestBannerState extends ConsumerState<_RequestBanner> {
  _RequestBannerAction _action = _RequestBannerAction.none;

  Future<void> _handle(_RequestBannerAction action) async {
    if (_action != _RequestBannerAction.none) return;
    setState(() => _action = action);

    final notifier = ref.read(chatControllerProvider.notifier);
    final success = action == _RequestBannerAction.accepting
        ? await notifier.acceptRequest(widget.chatId)
        : await notifier.declineRequest(widget.chatId);

    if (!mounted) return;
    setState(() => _action = _RequestBannerAction.none);

    if (!success) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.chatRequestActionErrorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final busy = _action != _RequestBannerAction.none;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        _Spacing.lg,
        _Spacing.md,
        _Spacing.lg,
        _Spacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.chatRequestBannerTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ChatLightColors.ink,
              ),
            ),
            const SizedBox(height: _Spacing.xs),
            Text(
              loc.chatRequestBannerSubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: ChatLightColors.inkFaint,
              ),
            ),
            const SizedBox(height: _Spacing.md + 2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    // Local override — the app-wide OutlinedButtonTheme
                    // assumes a dark background (white text, dark
                    // border), which reads as broken on this screen's
                    // light exception theme.
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ChatLightColors.ink,
                      side: const BorderSide(color: Colors.black26, width: 1.2),
                    ),
                    onPressed: busy
                        ? null
                        : () => _handle(_RequestBannerAction.declining),
                    child: _action == _RequestBannerAction.declining
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ChatLightColors.inkSoft,
                            ),
                          )
                        : Text(loc.chatRequestDeclineButton),
                  ),
                ),
                const SizedBox(width: _Spacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () => _handle(_RequestBannerAction.accepting),
                    child: _action == _RequestBannerAction.accepting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : Text(loc.chatRequestAcceptButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingNotice extends StatelessWidget {
  final AppLocalizations loc;

  const _PendingNotice({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        _Spacing.lg,
        _Spacing.md,
        _Spacing.lg,
        _Spacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Text(
          loc.chatRequestPendingNotice,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: ChatLightColors.inkFaint),
        ),
      ),
    );
  }
}

/// Shown in place of the composer once a request has been declined — no
/// Send button is rendered here at all, so there is no way for the UI to
/// fire another send write for this chat.
class _DeclinedNotice extends StatelessWidget {
  final AppLocalizations loc;
  final bool iAmInitiator;

  const _DeclinedNotice({required this.loc, required this.iAmInitiator});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        _Spacing.lg,
        _Spacing.md,
        _Spacing.lg,
        _Spacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_outlined, size: 16, color: AppColors.error),
            const SizedBox(width: _Spacing.sm),
            Flexible(
              child: Text(
                iAmInitiator
                    ? loc.chatRequestDeclinedByPeerNotice
                    : loc.chatRequestDeclinedNotice,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp/Telegram-style composer bar: Attachment on the far left, the
/// text field in the middle, Camera next, and a trailing button that's
/// either Send (text present) or a press-and-hold voice recorder (empty).
class _Composer extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUid;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _Composer({
    required this.chatId,
    required this.otherUid,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  /// WhatsApp's own ceiling for a single voice note — past this, recording
  /// stops on its own and drops straight into the review step below
  /// rather than silently cutting the clip off mid-word.
  static const _maxRecordingDuration = Duration(seconds: 60);

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _cancelRecording = false;

  /// True once the user has dragged the mic up past the lock threshold —
  /// from then on releasing the finger no longer stops the recording;
  /// only the explicit "Bitir" control (or the 60s cap) does.
  bool _isLocked = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  DateTime? _recordStartedAt;

  /// Non-null once a locked (or 60s-capped) recording has finished and
  /// is sitting in the review step — play it back, then explicitly send
  /// or delete it. The plain press-hold-release flow never populates
  /// this; it keeps sending immediately on release, same as before.
  File? _reviewFile;
  Duration _reviewDuration = Duration.zero;

  bool _fieldFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _fieldFocused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<MessageType>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_Spacing.lg)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: _Spacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _Spacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loc.chatAttachmentSheetTitle,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: _Spacing.sm),
              ListTile(
                leading: const Icon(
                  Icons.image_outlined,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  loc.chatAttachmentImageOption,
                  style: AppTextStyles.body.copyWith(fontSize: 15),
                ),
                onTap: () => Navigator.pop(sheetContext, MessageType.image),
              ),
              ListTile(
                leading: const Icon(
                  Icons.videocam_outlined,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  loc.chatAttachmentVideoOption,
                  style: AppTextStyles.body.copyWith(fontSize: 15),
                ),
                onTap: () => Navigator.pop(sheetContext, MessageType.video),
              ),
              const SizedBox(height: _Spacing.sm),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? picked = choice == MessageType.image
        ? await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            imageQuality: 85,
          )
        : await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 2),
          );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final action = await Navigator.push<MediaPreviewAction>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaSendPreviewScreen(file: file, type: choice),
      ),
    );
    if (action != MediaPreviewAction.send || !mounted) return;

    final notifier = ref.read(pendingMessagesProvider.notifier);
    if (choice == MessageType.image) {
      notifier.sendImage(
        chatId: widget.chatId,
        otherUid: widget.otherUid,
        file: file,
      );
    } else {
      notifier.sendVideo(
        chatId: widget.chatId,
        otherUid: widget.otherUid,
        file: file,
      );
    }
  }

  Future<void> _takePhoto() async {
    if (!mounted) return;
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (e, st) {
      logError('chat_composer.takePhoto', e, st);
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.chatCameraPermissionDeniedMessage)),
      );
      return;
    }
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final action = await Navigator.push<MediaPreviewAction>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaSendPreviewScreen(
          file: file,
          type: MessageType.image,
          allowRetake: true,
        ),
      ),
    );
    if (!mounted) return;
    if (action == MediaPreviewAction.retake) {
      await _takePhoto();
      return;
    }
    if (action == MediaPreviewAction.send) {
      ref
          .read(pendingMessagesProvider.notifier)
          .sendImage(
            chatId: widget.chatId,
            otherUid: widget.otherUid,
            file: file,
          );
    }
  }

  Future<void> _startRecording() async {
    if (!mounted) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.chatMicPermissionDeniedMessage)),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _recordStartedAt = DateTime.now();
    _cancelRecording = false;
    _isLocked = false;
    if (!mounted) return;
    setState(() => _isRecording = true);

    _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_recordStartedAt!);
      setState(() => _recordDuration = elapsed);
      if (elapsed >= _maxRecordingDuration) {
        // Cap hit — finish into the review step regardless of whether
        // the user ever locked it or is still holding the button down.
        _finishRecording(cancel: false, toReview: true);
      }
    });
  }

  /// Tracks the long-press drag in both directions: left = cancel
  /// (existing behaviour), up past the lock threshold = lock the
  /// recording so releasing the finger no longer ends it. Once locked,
  /// further drag is ignored — there's nothing left to decide.
  void _updateDrag(double dxFromOrigin, double dyFromOrigin) {
    if (_isLocked) return;

    if (dyFromOrigin < -80) {
      setState(() {
        _isLocked = true;
        _cancelRecording = false;
      });
      return;
    }

    final shouldCancel = dxFromOrigin < -60;
    if (shouldCancel != _cancelRecording) {
      setState(() => _cancelRecording = shouldCancel);
    }
  }

  /// Only called when NOT locked — a plain press-hold-release. Keeps
  /// its original behaviour exactly: sends immediately on release,
  /// never goes through the review step.
  Future<void> _finishOnRelease() {
    return _finishRecording(cancel: _cancelRecording, toReview: false);
  }

  /// Called by the explicit "Bitir" control once locked, and by the
  /// 60s cap regardless of lock state.
  Future<void> _finishToReview() {
    return _finishRecording(cancel: false, toReview: true);
  }

  Future<void> _finishRecording({
    required bool cancel,
    required bool toReview,
  }) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final path = await _recorder.stop();
    final duration = _recordDuration;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _recordDuration = Duration.zero;
      });
    }

    if (path == null) return;
    final file = File(path);

    if (cancel) {
      if (await file.exists()) await file.delete();
      return;
    }

    if (duration.inMilliseconds < 700) {
      if (await file.exists()) await file.delete();
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.chatVoiceTooShortMessage)));
      return;
    }

    if (toReview) {
      if (!mounted) return;
      setState(() {
        _reviewFile = file;
        _reviewDuration = duration;
      });
      return;
    }

    ref
        .read(pendingMessagesProvider.notifier)
        .sendAudio(
          chatId: widget.chatId,
          otherUid: widget.otherUid,
          file: file,
          durationMs: duration.inMilliseconds,
        );
  }

  Future<void> _discardReview() async {
    final file = _reviewFile;
    setState(() {
      _reviewFile = null;
      _reviewDuration = Duration.zero;
    });
    if (file != null && await file.exists()) await file.delete();
  }

  void _sendReview() {
    final file = _reviewFile;
    final duration = _reviewDuration;
    if (file == null) return;
    setState(() {
      _reviewFile = null;
      _reviewDuration = Duration.zero;
    });
    ref
        .read(pendingMessagesProvider.notifier)
        .sendAudio(
          chatId: widget.chatId,
          otherUid: widget.otherUid,
          file: file,
          durationMs: duration.inMilliseconds,
        );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final hasText = widget.controller.text.trim().isNotEmpty;
    final reviewing = _reviewFile != null;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: ChatLightColors.barTint.withValues(alpha: 0.6),
            border: const Border(
              top: BorderSide(color: Colors.black12, width: 0.6),
            ),
          ),
          // Right padding is deliberately larger than the other three sides —
          // the trailing mic/send button used to sit only 8px from the
          // physical screen edge, which made it easy to miss/hard to
          // press reliably (bezel proximity leaves little margin for
          // error). Nudging it in by a few more pixels keeps the whole
          // row visually balanced while giving that button real room.
          padding: const EdgeInsets.fromLTRB(
            _Spacing.sm,
            _Spacing.sm,
            _Spacing.md,
            _Spacing.sm,
          ),
          child: SafeArea(
            top: false,
            child: reviewing
                ? _VoiceReviewRow(
                    file: _reviewFile!,
                    durationMs: _reviewDuration.inMilliseconds,
                    onDiscard: _discardReview,
                    onSend: _sendReview,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: (widget.sending || _isRecording)
                            ? null
                            : _pickAttachment,
                        icon: const Icon(
                          Icons.attach_file_outlined,
                          color: ChatLightColors.inkSoft,
                        ),
                      ),
                      Expanded(
                        child: _isRecording
                            ? _RecordingInfo(
                                duration: _formatDuration(_recordDuration),
                                cancelling: _cancelRecording,
                                locked: _isLocked,
                                cancelHint: loc.chatRecordingCancelHint,
                                lockHint: loc.chatRecordingLockHint,
                                finishLabel: loc.chatVoiceFinishButton,
                                onFinish: _finishToReview,
                              )
                            : AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                decoration: BoxDecoration(
                                  color: ChatLightColors.composerFill,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    const BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      blurStyle: BlurStyle.inner,
                                    ),
                                    if (_fieldFocused)
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                  ],
                                ),
                                child: TextField(
                                  controller: widget.controller,
                                  focusNode: widget.focusNode,
                                  onChanged: widget.onChanged,
                                  minLines: 1,
                                  maxLines: 5,
                                  // Matches firestore.rules' new `text.size() <= 2000`
                                  // (Düzəliş Prompt 8 / RT-2) — no visible counter,
                                  // same silent-cap UX as a normal chat input.
                                  maxLength: 2000,
                                  buildCounter:
                                      (
                                        context, {
                                        required currentLength,
                                        required isFocused,
                                        maxLength,
                                      }) => null,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: ChatLightColors.ink,
                                  ),
                                  cursorColor: AppColors.primary,
                                  decoration: InputDecoration(
                                    hintText: loc.chatMessageHint,
                                    hintStyle: const TextStyle(
                                      color: ChatLightColors.inkFaint,
                                      fontSize: 15,
                                    ),
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: _Spacing.md,
                                      vertical: _Spacing.sm + 4,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (!_isRecording)
                        IconButton(
                          onPressed: widget.sending ? null : _takePhoto,
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: ChatLightColors.inkSoft,
                          ),
                        ),
                      const SizedBox(width: _Spacing.xs),
                      _TrailingActionButton(
                        hasText: hasText,
                        sending: widget.sending,
                        isRecording: _isRecording,
                        isLocked: _isLocked,
                        cancelling: _cancelRecording,
                        onSend: widget.onSend,
                        onRecordStart: () => _startRecording(),
                        onRecordMove: _updateDrag,
                        onRecordEnd: _finishOnRelease,
                        onRecordCancel: () =>
                            _finishRecording(cancel: true, toReview: false),
                        onLockedTap: _finishToReview,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RecordingInfo extends StatefulWidget {
  final String duration;
  final bool cancelling;
  final bool locked;
  final String cancelHint;
  final String lockHint;
  final String finishLabel;
  final VoidCallback onFinish;

  const _RecordingInfo({
    required this.duration,
    required this.cancelling,
    required this.locked,
    required this.cancelHint,
    required this.lockHint,
    required this.finishLabel,
    required this.onFinish,
  });

  @override
  State<_RecordingInfo> createState() => _RecordingInfoState();
}

class _RecordingInfoState extends State<_RecordingInfo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locked) return _buildLocked(context);
    return _buildUnlocked(context);
  }

  Widget _buildLocked(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          FadeTransition(
            opacity: _blinkController,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 10, height: 10),
            ),
          ),
          const SizedBox(width: _Spacing.sm),
          Text(
            widget.duration,
            style: AppTextStyles.body.copyWith(fontSize: 14.5),
          ),
          const Spacer(),
          Pressable(
            onTap: widget.onFinish,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _Spacing.sm + 2,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    widget.finishLabel,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlocked(BuildContext context) {
    final hintColor = widget.cancelling ? AppColors.error : AppColors.textMuted;
    final hintIcon = widget.cancelling
        ? Icons.chevron_left_rounded
        : Icons.keyboard_arrow_up_rounded;
    final hintText = widget.cancelling ? widget.cancelHint : widget.lockHint;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          FadeTransition(
            opacity: _blinkController,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 10, height: 10),
            ),
          ),
          const SizedBox(width: _Spacing.sm),
          Text(
            widget.duration,
            style: AppTextStyles.body.copyWith(fontSize: 14.5),
          ),
          const Spacer(),
          Icon(hintIcon, size: 18, color: hintColor),
          Flexible(
            child: Text(
              hintText,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                color: hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailingActionButton extends StatelessWidget {
  final bool hasText;
  final bool sending;
  final bool isRecording;
  final bool isLocked;
  final bool cancelling;
  final VoidCallback onSend;
  final VoidCallback onRecordStart;
  final void Function(double dx, double dy) onRecordMove;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;
  final VoidCallback onLockedTap;

  const _TrailingActionButton({
    required this.hasText,
    required this.sending,
    required this.isRecording,
    required this.isLocked,
    required this.cancelling,
    required this.onSend,
    required this.onRecordStart,
    required this.onRecordMove,
    required this.onRecordEnd,
    required this.onRecordCancel,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isRecording
        ? (cancelling ? AppColors.error : AppColors.primary)
        : AppColors.primary;
    // Once locked, releasing the finger must NOT stop the recording —
    // only the explicit "Bitir" control (which calls onLockedTap) may.
    final lockedAndRecording = isRecording && isLocked;

    return GestureDetector(
      onTap: hasText && !isRecording
          ? (sending ? null : onSend)
          : (lockedAndRecording ? onLockedTap : null),
      onLongPressStart: hasText ? null : (_) => onRecordStart(),
      onLongPressMoveUpdate: hasText
          ? null
          : (details) => onRecordMove(
              details.localOffsetFromOrigin.dx,
              details.localOffsetFromOrigin.dy,
            ),
      onLongPressEnd: (hasText || lockedAndRecording)
          ? null
          : (_) => onRecordEnd(),
      onLongPressCancel: (hasText || lockedAndRecording)
          ? null
          : onRecordCancel,
      // The tappable region is deliberately a few pixels bigger than the
      // visible 48x48 circle (still centered the same) — right next to
      // the screen edge, a hit-test box exactly matching the visual
      // circle leaves zero margin for a slightly-off finger.
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: sending
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onAccent,
                        ),
                      )
                    : Icon(
                        hasText ? Icons.send_outlined : Icons.mic_none_outlined,
                        key: ValueKey(hasText),
                        color: AppColors.onAccent,
                        size: 22,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The post-lock / post-60s-cap review step: lets the user preview the
/// just-recorded clip before deciding to send or discard it, per the
/// "istəyə görə göndər və ya sil" requirement.
class _VoiceReviewRow extends StatelessWidget {
  final File file;
  final int durationMs;
  final VoidCallback onDiscard;
  final VoidCallback onSend;

  const _VoiceReviewRow({
    required this.file,
    required this.durationMs,
    required this.onDiscard,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onDiscard,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: _Spacing.sm + 2,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _LocalVoicePreviewPlayer(file: file, durationMs: durationMs),
          ),
        ),
        const SizedBox(width: _Spacing.xs),
        // The most-tapped control in the app, and it gave NO visual
        // response at all — a slow send read as a tap that never
        // registered, so people pressed again. `InkWell` would not help:
        // `AppTheme` disables the ripple app-wide.
        Pressable(
          onTap: onSend,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_outlined,
              color: AppColors.onAccent,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

/// Local playback (pre-send) for the review step. Deliberately separate
/// from [AudioMessagePlayer] — that one streams a remote/sent message
/// URL, this one plays a local file that doesn't exist on the server yet.
class _LocalVoicePreviewPlayer extends StatefulWidget {
  final File file;
  final int durationMs;

  const _LocalVoicePreviewPlayer({
    required this.file,
    required this.durationMs,
  });

  @override
  State<_LocalVoicePreviewPlayer> createState() =>
      _LocalVoicePreviewPlayerState();
}

class _LocalVoicePreviewPlayerState extends State<_LocalVoicePreviewPlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  late final Duration _total = Duration(milliseconds: widget.durationMs);

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.file.path));
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      children: [
        Pressable(
          onTap: _toggle,
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _playing ? Icons.pause_outlined : Icons.play_arrow_outlined,
              color: AppColors.onAccent,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: _Spacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: _Spacing.sm),
        Text(
          _format(_playing || _position > Duration.zero ? _position : _total),
          style: AppTextStyles.caption.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}
