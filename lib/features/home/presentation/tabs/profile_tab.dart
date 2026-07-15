import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/coming_soon_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../location/presentation/providers/presence_provider.dart';
import '../../../onboarding/presentation/screens/welcome_screen.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final authUser = ref.watch(authControllerProvider).valueOrNull;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Profil',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary, width: 2),
                    image: profile.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(profile.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profile.photoUrl == null
                      ? const Icon(Icons.person, color: AppColors.primary, size: 34)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authUser?.name ?? 'Adını əlavə et',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.isComplete
                            ? profile.bio
                            : 'Şəkil, bio və maraqlarını əlavə et',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
          if (profile.interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests.map((interest) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    interest,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 28),
          _ProfileMenuItem(
            icon: Icons.badge_outlined,
            label: 'Profili redaktə et',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          _ProfileMenuItem(
            icon: Icons.verified_user_outlined,
            label: 'Kimlik doğrulama',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ComingSoonScreen(title: 'Kimlik doğrulama'),
              ),
            ),
          ),
          _ProfileMenuItem(icon: Icons.workspace_premium_outlined, label: 'Premium-a keç'),
          _ProfileMenuItem(icon: Icons.shield_outlined, label: 'Məxfilik və təhlükəsizlik'),
          _ProfileMenuItem(icon: Icons.notifications_outlined, label: 'Bildirişlər'),
          _ProfileMenuItem(icon: Icons.help_outline, label: 'Kömək'),
          const SizedBox(height: 12),
          _ProfileMenuItem(
            icon: Icons.logout,
            label: 'Çıxış et',
            danger: true,
            onTap: () async {
              await ref.read(presenceControllerProvider).setOffline();
              await ref.read(authControllerProvider.notifier).signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: danger ? AppColors.error : AppColors.primary, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w500)),
                ),
                if (!danger) const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
