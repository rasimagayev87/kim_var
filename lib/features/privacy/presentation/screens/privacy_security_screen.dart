import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/premium_upsell_sheet.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/country_dial_code.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../premium/presentation/providers/premium_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../safety/presentation/screens/blocked_users_screen.dart';
import '../../domain/entities/privacy_settings.dart';
import '../providers/privacy_providers.dart';
import 'active_devices_screen.dart';
import 'export_data_screen.dart';

class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final settingsAsync = ref.watch(privacySettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const PrivacySettings();
    final isPremium = ref.watch(isPremiumProvider);
    final controller = ref.read(privacySettingsControllerProvider);

    void showError() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.privacySettingUpdateErrorMessage)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.privacySecurityTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.visibility_outlined,
                  title: loc.privacyProfileVisibilityTitle,
                  subtitle: loc.privacyProfileVisibilitySubtitle,
                  trailing: SettingsPill(label: _visibilityLabel(loc, settings.profileVisibility)),
                  onTap: () => _showVisibilitySheet(
                    context: context,
                    loc: loc,
                    current: settings.profileVisibility,
                    onSelected: (v) async {
                      final ok = await controller.updateProfileVisibility(v);
                      if (!ok && context.mounted) showError();
                    },
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.radar_outlined,
                  title: loc.privacyRadiusTitle,
                  trailing: SettingsPill(label: _formatRadius(loc, settings)),
                  onTap: () => _showRadiusSheet(
                    context: context,
                    settings: settings,
                    isPremium: isPremium,
                    onSelected: (mode, km) async {
                      final ok = await controller.updateVisibilityRadius(mode, radiusKm: km);
                      if (!ok && context.mounted) showError();
                    },
                  ),
                ),
                SettingsToggleRow(
                  icon: Icons.visibility_off_outlined,
                  iconColor: AppColors.gold,
                  title: loc.privacyGhostModeTitle,
                  subtitle: loc.privacyGhostModeDescription,
                  value: settings.ghostModeEnabled,
                  badge: const SettingsPill(label: 'VIP', color: AppColors.gold),
                  onChanged: (v) async {
                    if (v && !isPremium) {
                      showPremiumUpsellSheet(
                        context,
                        title: loc.privacyGhostModePremiumTitle,
                        message: loc.privacyGhostModePremiumMessage,
                      );
                      return;
                    }
                    final ok = await controller.updateGhostMode(v);
                    if (!ok && context.mounted) showError();
                  },
                ),
                SettingsToggleRow(
                  icon: Icons.cake_outlined,
                  title: loc.privacyBirthdayOffersTitle,
                  subtitle: loc.privacyBirthdayOffersDescription,
                  value: settings.birthdayOffersOptIn,
                  onChanged: (v) async {
                    final ok = await controller.updateBirthdayOffersOptIn(v);
                    if (!ok && context.mounted) showError();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              children: [
                SettingsToggleRow(
                  icon: Icons.wifi_tethering,
                  title: loc.privacyOnlineStatusTitle,
                  value: settings.showOnlineStatus,
                  onChanged: (v) async {
                    final ok = await controller.updateShowOnlineStatus(v);
                    if (!ok && context.mounted) showError();
                  },
                ),
                SettingsToggleRow(
                  icon: Icons.done_all,
                  title: loc.privacyReadReceiptsTitle,
                  subtitle: loc.privacyReadReceiptsHelperText,
                  value: settings.showReadReceipts,
                  onChanged: (v) async {
                    final ok = await controller.updateShowReadReceipts(v);
                    if (!ok && context.mounted) showError();
                  },
                ),
                SettingsMenuRow(
                  icon: Icons.forum_outlined,
                  title: loc.privacyWhoCanMessageTitle,
                  trailing: SettingsPill(label: _whoCanMessageLabel(loc, settings.whoCanMessageMe)),
                  onTap: () => _showWhoCanMessageSheet(
                    context: context,
                    loc: loc,
                    current: settings.whoCanMessageMe,
                    onSelected: (v) async {
                      final ok = await controller.updateWhoCanMessageMe(v);
                      if (!ok && context.mounted) showError();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.block_outlined,
                  iconColor: AppColors.error,
                  title: loc.blockedUsersTitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.devices_outlined,
                  title: loc.activeDevicesTitle,
                  subtitle: loc.privacyActiveDevicesSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActiveDevicesScreen()),
                  ),
                ),
                SettingsMenuRow(
                  icon: Icons.verified_user_outlined,
                  title: loc.privacyTwoFactorTitle,
                  subtitle: loc.privacyTwoFactorHelperText,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (_) => _TwoFactorSheet(currentlyEnabled: settings.twoFactorEnabled),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.download_outlined,
                  title: loc.privacyExportDataTitle,
                  subtitle: loc.privacyExportDataDescription,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExportDataScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRadius(AppLocalizations loc, PrivacySettings settings) {
    switch (settings.visibilityRadiusMode) {
      case VisibilityRadiusMode.country:
        return loc.privacyRadiusCountryLabel;
      case VisibilityRadiusMode.world:
        return loc.privacyRadiusWorldLabel;
      case VisibilityRadiusMode.distance:
        final km = settings.visibilityRadiusKm ?? 1.0;
        return km >= 1 ? '${km.toStringAsFixed(0)} km' : '${(km * 1000).toStringAsFixed(0)} m';
    }
  }

  String _visibilityLabel(AppLocalizations loc, ProfileVisibility v) {
    switch (v) {
      case ProfileVisibility.everyone:
        return loc.privacyVisibilityEveryone;
      case ProfileVisibility.followersOnly:
        return loc.privacyVisibilityFollowersOnly;
      case ProfileVisibility.noOne:
        return loc.privacyVisibilityNoOne;
    }
  }

  String _whoCanMessageLabel(AppLocalizations loc, WhoCanMessageMe v) {
    switch (v) {
      case WhoCanMessageMe.everyone:
        return loc.privacyMessagePermEveryone;
      case WhoCanMessageMe.followersOnly:
        return loc.privacyMessagePermFollowersOnly;
    }
  }

  // Ghost Mode is fully decoupled from this setting now — it only ever
  // hides the user from the map/Discover (its own dedicated toggle
  // above). This sheet governs media visibility only, and offers all 3
  // levels directly since none of them are VIP-gated.
  void _showVisibilitySheet({
    required BuildContext context,
    required AppLocalizations loc,
    required ProfileVisibility current,
    required ValueChanged<ProfileVisibility> onSelected,
  }) {
    _showOptionsSheet<ProfileVisibility>(
      context: context,
      title: loc.privacyProfileVisibilityTitle,
      current: current,
      options: [
        _Option(ProfileVisibility.everyone, loc.privacyVisibilityEveryone),
        _Option(ProfileVisibility.followersOnly, loc.privacyVisibilityFollowersOnly),
        _Option(ProfileVisibility.noOne, loc.privacyVisibilityNoOne),
      ],
      onSelected: (value, locked) => onSelected(value),
    );
  }

  void _showWhoCanMessageSheet({
    required BuildContext context,
    required AppLocalizations loc,
    required WhoCanMessageMe current,
    required ValueChanged<WhoCanMessageMe> onSelected,
  }) {
    _showOptionsSheet<WhoCanMessageMe>(
      context: context,
      title: loc.privacyWhoCanMessageTitle,
      current: current,
      options: [
        _Option(WhoCanMessageMe.everyone, loc.privacyMessagePermEveryone),
        _Option(WhoCanMessageMe.followersOnly, loc.privacyMessagePermFollowersOnly),
      ],
      onSelected: (value, _) => onSelected(value),
    );
  }

  void _showRadiusSheet({
    required BuildContext context,
    required PrivacySettings settings,
    required bool isPremium,
    required void Function(VisibilityRadiusMode mode, double? km) onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RadiusSheetContent(settings: settings, isPremium: isPremium, onSelected: onSelected),
    );
  }
}

class _Option<T> {
  final T value;
  final String label;
  final bool locked;

  const _Option(this.value, this.label, {this.locked = false});
}

/// Shared bottom-sheet radio picker for every 3-way choice on this
/// screen (profile visibility / location sharing / who can message me)
/// — one generic implementation instead of three near-identical sheets.
void _showOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required T current,
  required List<_Option<T>> options,
  required void Function(T value, bool locked) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              for (final option in options)
                ListTile(
                  title: Text(option.label, style: AppTextStyles.body.copyWith(fontSize: 15.5)),
                  leading: Icon(
                    option.value == current ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: option.value == current ? AppColors.primary : AppColors.textMuted,
                  ),
                  trailing: option.locked ? const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 20) : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelected(option.value, option.locked);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// "Görünmə radiusu" sheet content — mirrors Discover's own radius
/// selector structure (3-option default row + "Daha çox" reveal for
/// 5/10/30 km + Ölkə üzrə + Dünya üzrə, same VIP gate via
/// `isPremiumRadiusKm`/[isPremium]), but drives this user's own
/// independent visibility setting rather than what they're currently
/// browsing the map at.
class _RadiusSheetContent extends ConsumerStatefulWidget {
  final PrivacySettings settings;
  final bool isPremium;
  final void Function(VisibilityRadiusMode mode, double? km) onSelected;

  const _RadiusSheetContent({required this.settings, required this.isPremium, required this.onSelected});

  @override
  ConsumerState<_RadiusSheetContent> createState() => _RadiusSheetContentState();
}

class _RadiusSheetContentState extends ConsumerState<_RadiusSheetContent> {
  bool _expanded = false;

  bool _isSelectedKm(double km) =>
      widget.settings.visibilityRadiusMode == VisibilityRadiusMode.distance && widget.settings.visibilityRadiusKm == km;

  void _pick(VisibilityRadiusMode mode, {double? km}) {
    Navigator.pop(context);
    widget.onSelected(mode, km);
  }

  void _handleLockedTap() {
    final loc = AppLocalizations.of(context);
    showPremiumUpsellSheet(context, title: loc.premiumUpsellRadiusTitle, message: loc.premiumUpsellRadiusMessage);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final myCountry = ref.watch(profileControllerProvider).country;
    final countryFlag = flagForCountryName(myCountry);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.privacyRadiusTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < kDefaultRadiusOptionsKm.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _RadiusPill(
                      km: kDefaultRadiusOptionsKm[i],
                      selected: _isSelectedKm(kDefaultRadiusOptionsKm[i]),
                      locked: isPremiumRadiusKm(kDefaultRadiusOptionsKm[i]) && !widget.isPremium,
                      onTap: () {
                        final km = kDefaultRadiusOptionsKm[i];
                        if (isPremiumRadiusKm(km) && !widget.isPremium) {
                          _handleLockedTap();
                          return;
                        }
                        _pick(VisibilityRadiusMode.distance, km: km);
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (!_expanded)
              _MoreRadiusToggle(onTap: () => setState(() => _expanded = true))
            else ...[
              Row(
                children: [
                  for (var i = 0; i < kExtraRadiusOptionsKm.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _RadiusPill(
                        km: kExtraRadiusOptionsKm[i],
                        selected: _isSelectedKm(kExtraRadiusOptionsKm[i]),
                        locked: !widget.isPremium,
                        onTap: () {
                          if (!widget.isPremium) {
                            _handleLockedTap();
                            return;
                          }
                          _pick(VisibilityRadiusMode.distance, km: kExtraRadiusOptionsKm[i]);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SpecialRadiusPill(
                      selected: widget.settings.visibilityRadiusMode == VisibilityRadiusMode.country,
                      locked: !widget.isPremium,
                      onTap: () {
                        if (!widget.isPremium) {
                          _handleLockedTap();
                          return;
                        }
                        _pick(VisibilityRadiusMode.country);
                      },
                      child: countryFlag != null
                          ? Text(countryFlag, style: const TextStyle(fontSize: 20))
                          : const Icon(Icons.flag_outlined, color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SpecialRadiusPill(
                      selected: widget.settings.visibilityRadiusMode == VisibilityRadiusMode.world,
                      locked: !widget.isPremium,
                      onTap: () {
                        if (!widget.isPremium) {
                          _handleLockedTap();
                          return;
                        }
                        _pick(VisibilityRadiusMode.world);
                      },
                      child: const Icon(Icons.public_outlined, color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Same pill envelope as [_RadiusPill], styled as a neutral trigger
/// (never "selected") rather than a radius value.
class _MoreRadiusToggle extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreRadiusToggle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              loc.radiusMoreButtonLabel,
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_outlined, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Textless variant of [_RadiusPill] for Ölkə üzrə/Dünya üzrə — same
/// pill envelope, just a single centered icon/flag instead of a
/// distance label.
class _SpecialRadiusPill extends StatelessWidget {
  final Widget child;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _SpecialRadiusPill({
    required this.child,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : (locked ? AppColors.gold.withValues(alpha: 0.35) : AppColors.divider)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            child,
            if (locked)
              const Positioned(
                top: -2,
                right: 8,
                child: Icon(Icons.workspace_premium_outlined, size: 12, color: AppColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadiusPill extends StatelessWidget {
  final double km;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _RadiusPill({required this.km, required this.selected, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = km >= 1 ? '${km.toStringAsFixed(0)} km' : '${(km * 1000).toStringAsFixed(0)} m';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : (locked ? AppColors.gold.withValues(alpha: 0.35) : AppColors.divider)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) ...[
              const Icon(Icons.workspace_premium_rounded, size: 13, color: AppColors.gold),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onAccent : (locked ? AppColors.white : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "İki mərhələli doğrulama" — enabling requires a real SMS OTP
/// confirmation (reusing the same phone-reauth mechanism as delete-
/// account/change-phone); disabling doesn't need reauth.
class _TwoFactorSheet extends ConsumerStatefulWidget {
  final bool currentlyEnabled;

  const _TwoFactorSheet({required this.currentlyEnabled});

  @override
  ConsumerState<_TwoFactorSheet> createState() => _TwoFactorSheetState();
}

class _TwoFactorSheetState extends ConsumerState<_TwoFactorSheet> {
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _sending = false;
  bool _confirming = false;
  bool _disabling = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = fb.FirebaseAuth.instance.currentUser?.phoneNumber;
    final loc = AppLocalizations.of(context);
    if (phone == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(accountControllerProvider).sendReauthCode(
        phoneNumber: phone,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _sending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.deleteAccountCodeSentMessage)));
        },
        onFailed: () {
          if (!mounted) return;
          setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.deleteAccountReauthFailedMessage)));
        },
      );
    } catch (e, st) {
      logError('privacy_security_screen.twoFactor.sendCode', e, st);
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.deleteAccountReauthFailedMessage)));
    }
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;
    final code = _codeController.text.trim();
    if (verificationId == null || code.isEmpty) return;

    setState(() => _confirming = true);
    final loc = AppLocalizations.of(context);
    try {
      await ref.read(accountControllerProvider).confirmReauthCode(verificationId: verificationId, smsCode: code);
      final ok = await ref.read(privacySettingsControllerProvider).updateTwoFactorEnabled(true);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.privacySettingUpdateErrorMessage)));
      }
    } catch (e, st) {
      logError('privacy_security_screen.twoFactor.confirmCode', e, st);
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.deleteAccountReauthFailedMessage)));
    }
  }

  Future<void> _disable() async {
    setState(() => _disabling = true);
    final loc = AppLocalizations.of(context);
    final ok = await ref.read(privacySettingsControllerProvider).updateTwoFactorEnabled(false);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _disabling = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.privacySettingUpdateErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final codeRequested = _verificationId != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.currentlyEnabled ? loc.privacyTwoFactorTitle : loc.privacyTwoFactorActivateTitle,
              style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(loc.privacyTwoFactorHelperText, style: AppTextStyles.caption.copyWith(height: 1.4)),
            const SizedBox(height: 16),
            if (widget.currentlyEnabled)
              ElevatedButton(
                onPressed: _disabling ? null : _disable,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: _disabling
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(loc.privacyTwoFactorDisableButton),
              )
            else if (!codeRequested)
              ElevatedButton(
                onPressed: _sending ? null : _sendCode,
                child: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                    : Text(loc.deleteAccountSendCodeButton),
              )
            else ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.body.copyWith(fontSize: 15),
                decoration: InputDecoration(hintText: loc.deleteAccountOtpHint),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _confirming ? null : _confirmCode,
                child: _confirming
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                    : Text(loc.deleteAccountConfirmCodeButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
