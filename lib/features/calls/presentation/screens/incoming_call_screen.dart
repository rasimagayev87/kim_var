import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/call_session.dart';
import '../providers/call_providers.dart';
import 'call_screen.dart';

/// Pushed from `HomeScreen` the moment `incomingCallProvider` reports a
/// ringing call — the only place in the app that decides accept vs.
/// decline for a call this device didn't start. Only reachable while
/// the app is in the foreground (see `FirebaseCallRepository`'s doc
/// comment on background/killed-app limitations).
class IncomingCallScreen extends ConsumerStatefulWidget {
  final CallSession session;

  const IncomingCallScreen({super.key, required this.session});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  bool _responding = false;

  Future<void> _decline() async {
    if (_responding) return;
    setState(() => _responding = true);
    final navigator = Navigator.of(context);
    await ref.read(callRepositoryProvider).declineCall(widget.session.id);
    navigator.pop();
  }

  Future<void> _accept() async {
    if (_responding) return;
    setState(() => _responding = true);
    await ref.read(callRepositoryProvider).acceptCall(widget.session.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: widget.session.id,
          otherUid: widget.session.callerId,
          type: widget.session.type,
          isCaller: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final peer = ref.watch(publicProfileProvider(widget.session.callerId)).valueOrNull;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(loc.callStatusIncoming, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 64,
                backgroundColor: const Color(0xFF2A2A2A),
                backgroundImage: peer?.photoUrl != null ? NetworkImage(peer!.photoUrl!) : null,
                child: peer?.photoUrl == null
                    ? Text(
                        (peer?.name.isNotEmpty ?? false) ? peer!.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                peer?.name ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                widget.session.type == CallType.video ? loc.chatVideoCallLabel : loc.chatVoiceCallLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ResponseButton(
                      icon: Icons.call_end_rounded,
                      color: Colors.redAccent,
                      label: loc.callActionDecline,
                      onTap: _decline,
                    ),
                    _ResponseButton(
                      icon: Icons.call_rounded,
                      color: AppColors.cyanDark,
                      label: loc.callActionAccept,
                      onTap: _accept,
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

class _ResponseButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ResponseButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
