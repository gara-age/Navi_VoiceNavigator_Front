import 'package:flutter/material.dart';

import 'mode_launcher_page.dart';

class VoiceNavigatorApp extends StatelessWidget {
  const VoiceNavigatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:'Navi : Voice Navigator',
      debugShowCheckedModeBanner: false,
      home: ModeLauncherPage(),
    );
  }
}