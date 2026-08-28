import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_providers.dart';
import '../providers/app_config_providers.dart';

/// Refreshes Remote Config in the background whenever the app resumes
/// — same `WidgetsBindingObserver` shape as the fix already applied to
/// `discover_tab.dart` this session for the location-permission-resume
/// bug. Wraps [child] transparently; lives at the app root (see
/// `main.dart`'s `MaterialApp.builder`) rather than any one screen, so
/// a resume anywhere in the app keeps config fresh.
class AppConfigLifecycleObserver extends ConsumerStatefulWidget {
  const AppConfigLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppConfigLifecycleObserver> createState() => _AppConfigLifecycleObserverState();
}

class _AppConfigLifecycleObserverState extends ConsumerState<AppConfigLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final languageCode = ref.read(localeProvider).languageCode;
      ref.read(appConfigProvider.notifier).refresh(languageCode);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
