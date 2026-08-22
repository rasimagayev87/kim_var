import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/pinbox_order.dart';
import '../providers/pinbox_providers.dart';

/// PinBox Faza 8 — the QR ticket. The code isn't the [PinBoxOrder.id]
/// or any other static value — it's whatever `generatePinBoxQrToken`
/// (Cloud Function) most recently issued, re-requested on
/// [_kQrRefreshInterval] while [PinBoxOrderStatus.reserved] holds, so a
/// screenshot goes stale well before the viewing session ends. See that
/// function's own doc comment for the exact TTL/margin reasoning.
class PinBoxTicketScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PinBoxTicketScreen({super.key, required this.orderId});

  @override
  ConsumerState<PinBoxTicketScreen> createState() => _PinBoxTicketScreenState();
}

const _kQrRefreshInterval = Duration(seconds: 30);

/// Lets the buyer pick which maps app opens the route, instead of
/// hardcoding Google Maps — same three-way choice (Google/Apple/Waze)
/// `VenueProfileScreen`'s `_DirectionsRow` already offers, reusing its
/// exact URL schemes and l10n labels for consistency.
Future<void> _openDirectionsPicker(BuildContext context, double lat, double lng) async {
  final loc = AppLocalizations.of(context);

  Future<void> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: ChatLightColors.ink),
            title: Text(loc.venueDirectionsGoogleMaps, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
            onTap: () {
              Navigator.pop(sheetContext);
              open('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: ChatLightColors.ink),
            title: Text(loc.venueDirectionsAppleMaps, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
            onTap: () {
              Navigator.pop(sheetContext);
              open('https://maps.apple.com/?daddr=$lat,$lng');
            },
          ),
          ListTile(
            leading: const Icon(Icons.navigation_outlined, color: ChatLightColors.ink),
            title: Text(loc.venueDirectionsWaze, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
            onTap: () {
              Navigator.pop(sheetContext);
              open('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// "482913" → "482 913" — purely a legibility split for the 6-digit
/// code shown alongside the QR image; falls back to the raw value for
/// any other length so a future token-format change never breaks this.
String _formatQrCode(String token) {
  if (token.length != 6) return token;
  return '${token.substring(0, 3)} ${token.substring(3)}';
}

class _PinBoxTicketScreenState extends ConsumerState<PinBoxTicketScreen> {
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  String? _qrToken;
  DateTime? _qrExpiresAt;
  Duration _countdown = _kQrRefreshInterval;
  bool _qrLoading = false;
  bool _pollingActive = false;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Order arrives as `awaiting_payment` (Faza B — checkout has to open
  /// before the webhook can confirm anything), so polling can't just
  /// start unconditionally on mount the way it used to: a fetch before
  /// the order is actually [PinBoxOrderStatus.reserved] would fail once,
  /// permanently cancel the timer, and leave the ticket with no QR even
  /// after payment succeeds. Instead this is driven by the order stream
  /// itself (see the `ref.listen(..., fireImmediately: true)` call in
  /// [build]) — starts the moment [status] first becomes [reserved],
  /// whether that's on first load or after the webhook flips it live.
  void _startPollingIfNeeded(PinBoxOrderStatus status) {
    // `ref.listen(..., fireImmediately: true)` invokes this synchronously
    // from within `build`, where `setState` would throw — deferring every
    // state change to the next frame keeps this safe there AND on every
    // later, genuinely-async call (a harmless one-frame delay).
    if (status != PinBoxOrderStatus.reserved) {
      if (!_pollingActive) return;
      _pollingActive = false;
      _refreshTimer?.cancel();
      _countdownTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _qrToken = null;
          _qrLoading = false;
        });
      });
      return;
    }
    if (_pollingActive) return;
    _pollingActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _qrLoading = true);
    });
    _refreshQrToken();
    _refreshTimer = Timer.periodic(_kQrRefreshInterval, (_) => _refreshQrToken());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
  }

  Future<void> _refreshQrToken() async {
    try {
      final result = await ref.read(pinboxRepositoryProvider).generateQrToken(widget.orderId);
      if (!mounted) return;
      setState(() {
        _qrToken = result.qrToken;
        _qrExpiresAt = result.expiresAt;
        _qrLoading = false;
      });
    } catch (_) {
      // Order no longer 'reserved' (redeemed/expired) or outside the
      // pickup window — stop trying, the status badge below already
      // tells the buyer why there's no live code anymore.
      if (!mounted) return;
      setState(() => _qrLoading = false);
      _refreshTimer?.cancel();
    }
  }

  void _tickCountdown() {
    if (_qrExpiresAt == null || !mounted) return;
    final remaining = _qrExpiresAt!.difference(DateTime.now());
    setState(() => _countdown = remaining.isNegative ? Duration.zero : remaining);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final orderAsync = ref.watch(pinboxOrderByIdProvider(widget.orderId));

    // `WidgetRef.listen` (unlike the generator's `Ref.listen`) has no
    // `fireImmediately` — the `ref.watch` above already delivers the
    // current value on this build, so that's what covers "already
    // reserved on first load"; `listen` only needs to catch it moving
    // there LATER (e.g. the webhook confirming payment while this
    // screen is open).
    final currentStatus = orderAsync.valueOrNull?.status;
    if (currentStatus != null) _startPollingIfNeeded(currentStatus);

    ref.listen<AsyncValue<PinBoxOrder?>>(pinboxOrderByIdProvider(widget.orderId), (previous, next) {
      final status = next.valueOrNull?.status;
      if (status != null) _startPollingIfNeeded(status);
    });

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        title: Text(
          loc.pinboxTicketTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
          error: (_, _) => Center(child: Text(loc.pinboxTicketNotFoundMessage, style: const TextStyle(color: ChatLightColors.inkSoft))),
          data: (order) {
            if (order == null) {
              return Center(child: Text(loc.pinboxTicketNotFoundMessage, style: const TextStyle(color: ChatLightColors.inkSoft)));
            }
            final pinboxAsync = ref.watch(pinboxByIdProvider(order.pinboxId));
            return pinboxAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
              error: (_, _) => Center(child: Text(loc.pinboxTicketNotFoundMessage, style: const TextStyle(color: ChatLightColors.inkSoft))),
              data: (pinbox) {
                if (pinbox == null) {
                  return Center(child: Text(loc.pinboxTicketNotFoundMessage, style: const TextStyle(color: ChatLightColors.inkSoft)));
                }
                final pickupFormat = DateFormat('HH:mm');
                final savings = (pinbox.originalPrice - pinbox.pinboxPrice) * order.quantity;
                final orderCode = '#PK-${widget.orderId.substring(0, widget.orderId.length.clamp(0, 6)).toUpperCase()}';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.pinboxTicketTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ChatLightColors.inkSoft),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ChatLightColors.cardSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            orderCode,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.card)),
                      child: Column(
                        children: [
                          _StatusPill(status: order.status, loc: loc),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: pinbox.imageUrl != null
                                      ? AppImage(pinbox.imageUrl!, thumbnail: true, fit: BoxFit.cover)
                                      : Container(
                                          color: ChatLightColors.cardSurface,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.inventory_2_outlined, size: 20, color: ChatLightColors.inkSoft),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pinbox.venueName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                                    ),
                                    Text(
                                      loc.pinboxTicketItemLabel(pinbox.title, order.quantity),
                                      style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (order.status == PinBoxOrderStatus.reserved) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: ChatLightColors.inkFaint.withValues(alpha: 0.3), style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(AppRadii.card),
                              ),
                              child: Column(
                                children: [
                                  if (_qrLoading)
                                    const SizedBox(
                                      width: 196,
                                      height: 196,
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
                                    )
                                  else if (_qrToken == null)
                                    SizedBox(
                                      width: 196,
                                      height: 196,
                                      child: Center(
                                        child: Text(
                                          loc.pinboxTicketQrUnavailableMessage,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                                        ),
                                      ),
                                    )
                                  else
                                    QrImageView(
                                      data: _qrToken!,
                                      version: QrVersions.auto,
                                      size: 196,
                                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ChatLightColors.ink),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: ChatLightColors.ink,
                                      ),
                                    ),
                                  if (_qrToken != null) ...[
                                    const SizedBox(height: 14),
                                    // The code itself, not just the QR image encoding
                                    // it — PinBox Faza 9's redemption screen is
                                    // manual-entry-only (no camera scanning), so the
                                    // buyer needs something they can actually read
                                    // aloud or type in themselves when the cashier
                                    // has no scanner.
                                    Text(
                                      _formatQrCode(_qrToken!),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: ChatLightColors.ink,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Text(
                                    loc.pinboxTicketQrRefreshCountdown(_countdown.inSeconds),
                                    style: const TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              loc.pinboxTicketShowToCashierHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.card)),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: loc.pinboxPickupWindowLabel,
                            value:
                                '${pickupFormat.format(pinbox.pickupWindowStart)} - ${pickupFormat.format(pinbox.pickupWindowEnd)}',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(label: loc.pinboxTicketAmountPaidLabel, value: '${order.amountPaid.toStringAsFixed(2)} AZN'),
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: loc.pinboxTicketSavingsLabel,
                            value: '${savings.toStringAsFixed(2)} AZN',
                            valueColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.card)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pinbox.venueName,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                                ),
                                Text(
                                  pinbox.address,
                                  style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _openDirectionsPicker(context, pinbox.lat, pinbox.lng),
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: Text(loc.pinboxTicketOpenRouteButton),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final PinBoxOrderStatus status;
  final AppLocalizations loc;

  const _StatusPill({required this.status, required this.loc});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PinBoxOrderStatus.awaitingPayment => (loc.pinboxOrderStatusAwaitingPayment, AppColors.gold),
      PinBoxOrderStatus.reserved => (loc.pinboxOrderStatusReserved, AppColors.primary),
      PinBoxOrderStatus.paymentFailed => (loc.pinboxOrderStatusPaymentFailed, AppColors.error),
      PinBoxOrderStatus.completed => (loc.pinboxOrderStatusCompleted, AppColors.gold),
      PinBoxOrderStatus.expired => (loc.pinboxOrderStatusExpired, AppColors.error),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: ChatLightColors.inkSoft)),
        Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: valueColor ?? ChatLightColors.ink)),
      ],
    );
  }
}
