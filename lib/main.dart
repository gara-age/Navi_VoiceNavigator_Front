import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Navi startup Directory.current.path = ${Directory.current.path}');
  runApp(const ProviderScope(child: VoiceNavigatorApp()));
}
