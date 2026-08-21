import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../features/chat/presentation/theme/chat_light_theme.dart';
import '../theme/app_colors.dart';

/// Hosts Epoint's Apple Pay "Token Widget" (see `createApplePayCheckout`,
/// functions/src/index.ts) — their own hosted iframe/page where the
/// customer actually completes the Apple Pay sheet. This screen never
/// itself decides success/failure: the real confirmation is
/// `epointWebhook` flipping the underlying `payments` doc, which
/// whatever screen presented this checkout is already listening to
/// (same as the plain card-redirect flow). The `message` event Epoint's
/// docs describe firing inside the widget is bridged here purely so
/// this screen can auto-close instead of leaving the customer staring
/// at a "payment successful" page with no way back — if the bridge
/// never fires for any reason, the manual back button still works and
/// the payment itself is unaffected.
class EpointTokenWidgetScreen extends StatefulWidget {
  final String widgetUrl;

  const EpointTokenWidgetScreen({super.key, required this.widgetUrl});

  @override
  State<EpointTokenWidgetScreen> createState() => _EpointTokenWidgetScreenState();
}

class _EpointTokenWidgetScreenState extends State<EpointTokenWidgetScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('PeakPinBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
            // Epoint's widget page posts its result via the standard
            // browser `message` event (see their own docs' JS sample) —
            // that only reaches native code if something inside the
            // page relays it to a channel, so this injects exactly that
            // relay once the page has actually loaded.
            _controller.runJavaScript('''
              window.addEventListener('message', function(event) {
                PeakPinBridge.postMessage(JSON.stringify(event.data));
              });
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.widgetUrl));
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final decoded = jsonDecode(message.message) as Map<String, dynamic>;
      if (decoded['status'] == 'success' || decoded['status'] == 'error') {
        Navigator.pop(context);
      }
    } catch (_) {
      // Not JSON, or not the shape we expect — ignore, the manual back
      // button is still there.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: ChatLightColors.ink),
        ),
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
