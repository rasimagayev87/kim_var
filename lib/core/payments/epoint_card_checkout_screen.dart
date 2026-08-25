import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../features/chat/presentation/theme/chat_light_theme.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Hosts Epoint's card-checkout hosted page (`createEpointCheckout`,
/// functions/src/index.ts) inside the app instead of handing the
/// customer off to the external browser — same "wrap Epoint's own
/// page in a branded WebView" shape as `EpointTokenWidgetScreen`
/// (Apple Pay), just for the plain card flow. Epoint's own page
/// content (card fields, and yes, the merchant VÖEN/phone footer) is
/// still theirs — there's no API to collect card data directly (see
/// this file's sibling doc comments) — this only removes the jump out
/// of the app and lets the caller show its own result UI instead of
/// Epoint's `success_redirect_url`/`error_redirect_url` landing pages.
///
/// Pops `true` once navigation reaches `successRedirectUrl`, `false`
/// once it reaches `errorRedirectUrl`, or `null` if the customer just
/// closes the screen manually. This is a heuristic, not the payment's
/// source of truth — `epointWebhook` already confirmed (or didn't)
/// server-side before either redirect page would ever load.
class EpointCardCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;

  const EpointCardCheckoutScreen({super.key, required this.checkoutUrl});

  @override
  State<EpointCardCheckoutScreen> createState() => _EpointCardCheckoutScreenState();
}

class _EpointCardCheckoutScreenState extends State<EpointCardCheckoutScreen> {
  static const _successRedirectPrefix = 'https://admin.peakpin.app/payment/success';
  static const _errorRedirectPrefix = 'https://admin.peakpin.app/payment/error';

  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith(_successRedirectPrefix)) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(_errorRedirectPrefix)) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: ChatLightColors.ink),
        ),
        title: Text(
          loc.epointCardOption,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
        ],
      ),
    );
  }
}
