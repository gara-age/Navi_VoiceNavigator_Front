import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/settings_models.dart';

enum AppToastState {
  info,
  listening,
  processing,
  success,
  error,
  warning,
}

void showAppToast(
  BuildContext context,
  String message, {
  String title = 'Navi: Voice Navigator',
  AppToastState? state,
  DisplaySettings? displaySettings,
  int durationMs = 2400,
}) {
  final resolvedState = state ?? _inferToastState(title, message);

  _ToastOverlay.instance.show(
    context,
    title: title,
    message: message,
    state: resolvedState,
    displaySettings: displaySettings,
    durationMs: durationMs,
  );
}

AppToastState _inferToastState(String title, String message) {
  final source = '$title $message'.toLowerCase();

  if (source.contains('실패') ||
      source.contains('오류') ||
      source.contains('연결하지 못했습니다')) {
    return AppToastState.error;
  }

  if (source.contains('경고') ||
      source.contains('재시도') ||
      source.contains('지연')) {
    return AppToastState.warning;
  }

  if (source.contains('듣고 있습니다') ||
      source.contains('음성 수신') ||
      source.contains('listening')) {
    return AppToastState.listening;
  }

  if (source.contains('처리 중') ||
      source.contains('처리하고 있습니다') ||
      source.contains('processing')) {
    return AppToastState.processing;
  }

  if (source.contains('완료') ||
      source.contains('성공') ||
      source.contains('읽어드립니다')) {
    return AppToastState.success;
  }

  return AppToastState.info;
}

class _ToastOverlay {
  _ToastOverlay._();

  static final _ToastOverlay instance = _ToastOverlay._();

  OverlayEntry? _entry;
  Timer? _dismissTimer;

  void show(
    BuildContext context, {
    required String title,
    required String message,
    required AppToastState state,
    required DisplaySettings? displaySettings,
    required int durationMs,
  }) {
    _dismissTimer?.cancel();
    _entry?.remove();

    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (context) {
        return _ToastView(
          title: title,
          message: message,
          state: state,
          displaySettings: displaySettings,
        );
      },
    );

    overlay.insert(_entry!);

    _dismissTimer = Timer(Duration(milliseconds: durationMs), () {
      _entry?.remove();
      _entry = null;
    });
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({
    required this.title,
    required this.message,
    required this.state,
    required this.displaySettings,
  });

  final String title;
  final String message;
  final AppToastState state;
  final DisplaySettings? displaySettings;

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(state);
    final icon = _resolveIcon(state);
    final largeText = displaySettings?.largeText ?? false;

    return Positioned(
      top: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: largeText ? 360 : 320,
          padding: EdgeInsets.all(largeText ? 18 : 16),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: palette.iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: largeText ? 15 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: largeText ? 14 : 13,
                        height: 1.45,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _resolveIcon(AppToastState state) {
  switch (state) {
    case AppToastState.info:
      return Icons.info_outline_rounded;
    case AppToastState.listening:
      return Icons.mic_rounded;
    case AppToastState.processing:
      return Icons.hourglass_top_rounded;
    case AppToastState.success:
      return Icons.check_rounded;
    case AppToastState.error:
      return Icons.error_outline_rounded;
    case AppToastState.warning:
      return Icons.warning_amber_rounded;
  }
}

_ToastPalette _resolvePalette(AppToastState state) {
  switch (state) {
    case AppToastState.info:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFE2E8F0),
        iconBackground: Color(0xFFEFF6FF),
        iconColor: Color(0xFF2563EB),
      );
    case AppToastState.listening:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFBFDBFE),
        iconBackground: Color(0xFFEFF6FF),
        iconColor: Color(0xFF2563EB),
      );
    case AppToastState.processing:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFFDE68A),
        iconBackground: Color(0xFFFEF3C7),
        iconColor: Color(0xFFF59E0B),
      );
    case AppToastState.success:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFBBF7D0),
        iconBackground: Color(0xFFDCFCE7),
        iconColor: Color(0xFF16A34A),
      );
    case AppToastState.error:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFFECACA),
        iconBackground: Color(0xFFFEE2E2),
        iconColor: Color(0xFFDC2626),
      );
    case AppToastState.warning:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFFDE68A),
        iconBackground: Color(0xFFFFF7ED),
        iconColor: Color(0xFFEA580C),
      );
  }
}

class _ToastPalette {
  const _ToastPalette({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
  });

  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
}
