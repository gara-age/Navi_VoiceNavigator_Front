import 'dart:io';

import 'package:flutter/services.dart';

class WindowControlService {
  WindowControlService._();

  static final WindowControlService instance = WindowControlService._();

  static const MethodChannel _channel =
      MethodChannel('voice_navigator/window_control');

  bool get supportsCustomChrome => Platform.isWindows;

  Future<void> minimize() async {
    if (!supportsCustomChrome) {
      return;
    }
    await _invoke('minimize');
  }

  Future<void> maximizeOrRestore() async {
    if (!supportsCustomChrome) {
      return;
    }
    await _invoke('maximizeOrRestore');
  }

  Future<void> close() async {
    if (!supportsCustomChrome) {
      return;
    }
    await _invoke('close');
  }

  Future<void> startDrag() async {
    if (!supportsCustomChrome) {
      return;
    }
    await _invoke('startDrag');
  }

  Future<void> startResize(String direction) async {
    if (!supportsCustomChrome) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('startResize', {
        'direction': direction,
      });
    } catch (_) {
      // Ignore native resize failures and keep the app responsive.
    }
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Ignore native window control failures and keep the app responsive.
    }
  }
}
