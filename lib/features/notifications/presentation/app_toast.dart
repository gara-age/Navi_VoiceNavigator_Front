import 'dart:async';

import 'package:flutter/material.dart';

enum AppToastState {
  info,
  listening,
  processing,
  success,
}

void showAppToast(
  BuildContext context,
  String message, {
  String title = 'Navi: Voice Navigator',
  AppToastState state = AppToastState.info,
  int durationMs = 2200,
}) {
  _ToastOverlay.instance.show(
    context,
    title: title,
    message: message,
    state: state,
    durationMs: durationMs,
  );
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
  });

  final String title;
  final String message;
  final AppToastState state;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(state);
    final icon = _resolveIcon(state);

    return Positioned(
      top: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
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
                  color: colors.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: colors.iconColor,
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF475569),
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
  }
}

_ToastColors _resolveColors(AppToastState state) {
  switch (state) {
    case AppToastState.info:
      return const _ToastColors(
        background: Colors.white,
        border: Color(0xFFE2E8F0),
        iconBackground: Color(0xFFEFF6FF),
        iconColor: Color(0xFF2563EB),
      );
    case AppToastState.listening:
      return const _ToastColors(
        background: Colors.white,
        border: Color(0xFFBFDBFE),
        iconBackground: Color(0xFFEFF6FF),
        iconColor: Color(0xFF2563EB),
      );
    case AppToastState.processing:
      return const _ToastColors(
        background: Colors.white,
        border: Color(0xFFFDE68A),
        iconBackground: Color(0xFFFEF3C7),
        iconColor: Color(0xFFF59E0B),
      );
    case AppToastState.success:
      return const _ToastColors(
        background: Colors.white,
        border: Color(0xFFBBF7D0),
        iconBackground: Color(0xFFDCFCE7),
        iconColor: Color(0xFF16A34A),
      );
  }
}

class _ToastColors {
  const _ToastColors({
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
