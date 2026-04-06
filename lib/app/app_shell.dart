import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_controller.dart';
import 'mode_launcher_page.dart';
import 'theme/app_theme.dart';

class VoiceNavigatorApp extends ConsumerStatefulWidget {
  const VoiceNavigatorApp({
    super.key,
    this.home,
  });

  final Widget? home;

  @override
  ConsumerState<VoiceNavigatorApp> createState() => _VoiceNavigatorAppState();
}

class _VoiceNavigatorAppState extends ConsumerState<VoiceNavigatorApp> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(settingsControllerProvider.notifier).load();
      if (mounted) {
        setState(() => _loaded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'Navi: Voice Navigator',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(display: settings.display),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scale = settings.display.largeText ? 1.32 : 1.0;

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Pretendard'),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: _loaded
          ? (widget.home ?? const ModeLauncherPage())
          : const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.8),
                ),
              ),
            ),
    );
  }
}
