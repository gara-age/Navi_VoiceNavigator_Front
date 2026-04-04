import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_controller.dart';
import 'mode_launcher_page.dart';

class VoiceNavigatorApp extends ConsumerStatefulWidget {
  const VoiceNavigatorApp({super.key});

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
    return MaterialApp(
      title: 'Navi: Voice Navigator',
      debugShowCheckedModeBanner: false,
      home: _loaded
          ? const ModeLauncherPage()
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}
