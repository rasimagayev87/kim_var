import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../providers/profile_visitors_providers.dart';
import '../providers/public_profile_providers.dart';

/// Real-time list of who viewed the signed-in user's profile in the
/// last 30 days (see profile_visitors_providers.dart) — only ever
/// opened on your OWN [uid] (the footprint button in ProfileTab), but
/// takes it as a param rather than reading FirebaseAuth directly so the
/// screen itself stays a plain, testable consumer of the uid it's given.
class ProfileVisitorsScreen extends ConsumerWidget {
  final String uid;

  const ProfileVisitorsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final visitorsAsync = ref.watch(profileVisitorsProvider(uid));

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1,
        elevation: 0,
        foregroundColor: ChatLightColors.ink,
        title: Text(
          loc.profileVisitorsTitle,
          style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: visitorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ChatLightColors.ink)),
        error: (_, _) => Center(
          child: Text(loc.profileVisitorsEmptyMessage, style: const TextStyle(color: ChatLightColors.inkFaint)),
        ),
        data: (visitors) {
          if (visitors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_walk, size: 48, color: ChatLightColors.inkFaint),
                    const SizedBox(height: 16),
                    Text(
                      loc.profileVisitorsEmptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visitors.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: ChatLightColors.cardSurface),
            itemBuilder: (context, index) => _VisitorTile(visit: visitors[index]),
          );
        },
      ),
    );
  }
}

class _VisitorTile extends ConsumerWidget {
  final ProfileVisit visit;

  const _VisitorTile({required this.visit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = ref.watch(publicProfileProvider(visit.viewerId)).valueOrNull;
    final name = profile?.name ?? '…';
    final photoUrl = profile?.photoUrl;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: ChatLightColors.cardSurface,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null ? const Icon(Icons.person_outline, color: ChatLightColors.inkSoft) : null,
      ),
      title: Text(name, style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        formatRelativeTime(visit.viewedAt, loc),
        style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 12.5),
      ),
    );
  }
}
