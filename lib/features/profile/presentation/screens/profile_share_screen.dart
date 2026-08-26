import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';

const double _avatarSize = 88;

/// TikTok-shaped "share your profile" card — same structural pattern
/// (overlapping circular avatar, name/@handle, centered QR, two share
/// actions) but drawn in the app's own light `ChatLightColors` palette
/// instead of TikTok's dark gradient, per the feature's own design
/// direction. Reuses `share_plus` (already wired for post sharing, see
/// `post_share_sheet.dart`) for the external share button — no new
/// native share-sheet plumbing.
class ProfileShareScreen extends StatelessWidget {
  final String name;
  final String username;
  final String? photoUrl;

  const ProfileShareScreen({super.key, required this.name, required this.username, this.photoUrl});

  String get _profileLink => 'https://peakpin.app/u/$username';

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _profileLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).profileLinkCopiedMessage)),
    );
  }

  Future<void> _shareLink() => Share.share(_profileLink);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: ChatLightColors.ink,
        centerTitle: true,
        title: Text(
          loc.shareProfileLabel,
          style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShareCard(name: name, username: username, photoUrl: photoUrl, link: _profileLink),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _copyLink(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ChatLightColors.ink,
                          side: const BorderSide(color: ChatLightColors.cardSurface),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          loc.copyProfileLinkLabel,
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _shareLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          loc.shareProfileLinkButtonLabel,
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final String name;
  final String username;
  final String? photoUrl;
  final String link;

  const _ShareCard({required this.name, required this.username, required this.photoUrl, required this.link});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: _avatarSize / 2),
          padding: EdgeInsets.fromLTRB(24, _avatarSize / 2 + 16, 24, 28),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '@$username',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: ChatLightColors.inkSoft),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ChatLightColors.cardSurface),
                ),
                child: QrImageView(
                  data: link,
                  version: QrVersions.auto,
                  size: 196,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ChatLightColors.ink),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: ChatLightColors.ink,
                  ),
                  embeddedImage: const AssetImage('assets/icon.png'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(32, 32)),
                ),
              ),
            ],
          ),
        ),
        _Avatar(photoUrl: photoUrl, name: name),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _Avatar({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ChatLightColors.bg2,
        border: Border.all(color: ChatLightColors.bg1, width: 4),
        image: photoUrl != null ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: photoUrl == null
          ? Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
              style: GoogleFonts.manrope(fontSize: 30, fontWeight: FontWeight.w800, color: ChatLightColors.inkSoft),
            )
          : null,
    );
  }
}
