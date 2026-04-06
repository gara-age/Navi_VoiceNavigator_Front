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

  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }

  void show(
    BuildContext context, {
    required String title,
    required String message,
    required AppToastState state,
    required DisplaySettings? displaySettings,
    required int durationMs,
  }) {
    dismiss();

    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (context) {
        return _ToastView(
          title: title,
          message: message,
          state: state,
          displaySettings: displaySettings,
          onClose: dismiss,
        );
      },
    );

    overlay.insert(_entry!);

    _dismissTimer = Timer(Duration(milliseconds: durationMs), () {
      dismiss();
    });
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({
    required this.title,
    required this.message,
    required this.state,
    required this.displaySettings,
    required this.onClose,
  });

  final String title;
  final String message;
  final AppToastState state;
  final DisplaySettings? displaySettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(state, displaySettings);
    final icon = _resolveIcon(state);
    final largeText = displaySettings?.largeText ?? false;
    final highContrast = displaySettings?.highContrast ?? false;

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
            border: Border.all(
              color: palette.border,
              width: palette.borderWidth,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.iconBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.iconBorder,
                          width: palette.iconBorderWidth,
                        ),
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
                              fontWeight: highContrast
                                  ? FontWeight.w900
                                  : FontWeight.w800,
                              color: palette.titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: largeText ? 14 : 13,
                              height: 1.45,
                              fontWeight: highContrast
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: palette.messageColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.closeBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: palette.closeBorder,
                          width: palette.closeBorderWidth,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: palette.closeColor,
                      ),
                    ),
                  ),
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

_ToastPalette _resolvePalette(
  AppToastState state,
  DisplaySettings? displaySettings,
) {
  final darkTheme = displaySettings?.darkTheme ?? false;
  final highContrast = displaySettings?.highContrast ?? false;

  if (darkTheme) {
    return _resolveDarkPalette(state, highContrast);
  }

  if (highContrast) {
    return _resolveHighContrastPalette(state);
  }

  switch (state) {
    case AppToastState.info:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFE2E8F0),
        iconBackground: Color(0xFFEFF6FF),
        iconColor: Color(0xFF2563EB),
        titleColor: Color(0xFF0F172A),
        messageColor: Color(0xFF475569),
        closeColor: Color(0xFF94A3B8),
        borderWidth: 1,
        iconBorder: Colors.transparent,
        iconBorderWidth: 0,
        closeBackground: Colors.transparent,
        closeBorder: Colors.transparent,
        closeBorderWidth: 0,
      );
    case AppToastState.listening:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFBFDBFE),
        iconBackground: Color(0xFFDBEAFE),
        iconColor: Color(0xFF2563EB),
        titleColor: Color(0xFF0F172A),
        messageColor: Color(0xFF475569),
        closeColor: Color(0xFF94A3B8),
        borderWidth: 1,
        iconBorder: Colors.transparent,
        iconBorderWidth: 0,
        closeBackground: Colors.transparent,
        closeBorder: Colors.transparent,
        closeBorderWidth: 0,
      );
    case AppToastState.processing:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFFDE68A),
        iconBackground: Color(0xFFFEF3C7),
        iconColor: Color(0xFFF59E0B),
        titleColor: Color(0xFF0F172A),
        messageColor: Color(0xFF475569),
        closeColor: Color(0xFF94A3B8),
        borderWidth: 1,
        iconBorder: Colors.transparent,
        iconBorderWidth: 0,
        closeBackground: Colors.transparent,
        closeBorder: Colors.transparent,
        closeBorderWidth: 0,
      );
    case AppToastState.success:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFBBF7D0),
        iconBackground: Color(0xFFDCFCE7),
        iconColor: Color(0xFF16A34A),
        titleColor: Color(0xFF0F172A),
        messageColor: Color(0xFF475569),
        closeColor: Color(0xFF94A3B8),
        borderWidth: 1,
        iconBorder: Colors.transparent,
        iconBorderWidth: 0,
        closeBackground: Colors.transparent,
        closeBorder: Colors.transparent,
        closeBorderWidth: 0,
      );
    case AppToastState.error:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFFECACA),
        iconBackground: Color(0xFFFEE2E2),
        iconColor: Color(0xFFDC2626),
        titleColor: Color(0xFF0F172A),
        messageColor: Color(0xFF475569),
        closeColor: Color(0xFF94A3B8),
        borderWidth: 1,
        iconBorder: Colors.transparent,
        iconBorderWidth: 0,
        closeBackground: Colors.transparent,
        closeBorder: Colors.transparent,
        closeBorderWidth: 0,
      );
    case AppToastState.warning:
      return const _ToastPalette(
        background: Colors.white,
        border: Color(0xFFFDE68A),
        iconBackground: Color(0xFFFFF7ED),
        iconColor: Color(0xFFEA580C),
        titleColor: Color(0xFF0F172A),
        messageColor: Color(0xFF475569),
        closeColor: Color(0xFF94A3B8),
        borderWidth: 1,
        iconBorder: Colors.transparent,
        iconBorderWidth: 0,
        closeBackground: Colors.transparent,
        closeBorder: Colors.transparent,
        closeBorderWidth: 0,
      );
  }
}

_ToastPalette _resolveHighContrastPalette(AppToastState state) {
  switch (state) {
    case AppToastState.info:
    case AppToastState.listening:
      return const _ToastPalette(
        background: Color(0xFFDBEAFE),
        border: Color(0xFF1E3A8A),
        iconBackground: Color(0xFFFFFFFF),
        iconColor: Color(0xFF1E3A8A),
        titleColor: Color(0xFF020617),
        messageColor: Color(0xFF1E3A8A),
        closeColor: Color(0xFF111827),
        borderWidth: 2,
        iconBorder: Color(0xFF1E3A8A),
        iconBorderWidth: 2,
        closeBackground: Color(0xFFFFFFFF),
        closeBorder: Color(0xFF1E3A8A),
        closeBorderWidth: 2,
      );
    case AppToastState.processing:
      return const _ToastPalette(
        background: Color(0xFFFEF9C3),
        border: Color(0xFF713F12),
        iconBackground: Color(0xFFFFFFFF),
        iconColor: Color(0xFF713F12),
        titleColor: Color(0xFF713F12),
        messageColor: Color(0xFF713F12),
        closeColor: Color(0xFF713F12),
        borderWidth: 2,
        iconBorder: Color(0xFF713F12),
        iconBorderWidth: 2,
        closeBackground: Color(0xFFFFFFFF),
        closeBorder: Color(0xFF713F12),
        closeBorderWidth: 2,
      );
    case AppToastState.success:
      return const _ToastPalette(
        background: Color(0xFFDCFCE7),
        border: Color(0xFF14532D),
        iconBackground: Color(0xFFFFFFFF),
        iconColor: Color(0xFF14532D),
        titleColor: Color(0xFF14532D),
        messageColor: Color(0xFF14532D),
        closeColor: Color(0xFF14532D),
        borderWidth: 2,
        iconBorder: Color(0xFF14532D),
        iconBorderWidth: 2,
        closeBackground: Color(0xFFFFFFFF),
        closeBorder: Color(0xFF14532D),
        closeBorderWidth: 2,
      );
    case AppToastState.error:
      return const _ToastPalette(
        background: Color(0xFFFEE2E2),
        border: Color(0xFF7F1D1D),
        iconBackground: Color(0xFFFFFFFF),
        iconColor: Color(0xFF7F1D1D),
        titleColor: Color(0xFF7F1D1D),
        messageColor: Color(0xFF7F1D1D),
        closeColor: Color(0xFF7F1D1D),
        borderWidth: 2,
        iconBorder: Color(0xFF7F1D1D),
        iconBorderWidth: 2,
        closeBackground: Color(0xFFFFFFFF),
        closeBorder: Color(0xFF7F1D1D),
        closeBorderWidth: 2,
      );
    case AppToastState.warning:
      return const _ToastPalette(
        background: Color(0xFFFFEDD5),
        border: Color(0xFF7C2D12),
        iconBackground: Color(0xFFFFFFFF),
        iconColor: Color(0xFF7C2D12),
        titleColor: Color(0xFF7C2D12),
        messageColor: Color(0xFF7C2D12),
        closeColor: Color(0xFF7C2D12),
        borderWidth: 2,
        iconBorder: Color(0xFF7C2D12),
        iconBorderWidth: 2,
        closeBackground: Color(0xFFFFFFFF),
        closeBorder: Color(0xFF7C2D12),
        closeBorderWidth: 2,
      );
  }
}

_ToastPalette _resolveDarkPalette(
  AppToastState state,
  bool highContrast,
) {
  switch (state) {
    case AppToastState.info:
      return _ToastPalette(
        background: highContrast ? const Color(0xFF020617) : const Color(0xFF0F172A),
        border: const Color(0xFF334155),
        iconBackground: const Color(0xFF1E3A8A),
        iconColor: const Color(0xFFBFDBFE),
        titleColor: Colors.white,
        messageColor: highContrast ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
        closeColor: const Color(0xFFE2E8F0),
        borderWidth: highContrast ? 2 : 1.5,
        iconBorder: const Color(0xFFBFDBFE),
        iconBorderWidth: highContrast ? 2 : 1,
        closeBackground: highContrast ? const Color(0xFF020617) : const Color(0xFF111827),
        closeBorder: const Color(0xFFE2E8F0),
        closeBorderWidth: highContrast ? 2 : 1,
      );
    case AppToastState.listening:
      return _ToastPalette(
        background: highContrast ? const Color(0xFF020617) : const Color(0xFF0F172A),
        border: const Color(0xFF3B82F6),
        iconBackground: const Color(0xFF1D4ED8),
        iconColor: const Color(0xFFDBEAFE),
        titleColor: Colors.white,
        messageColor: highContrast ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
        closeColor: const Color(0xFFDBEAFE),
        borderWidth: highContrast ? 2 : 1.5,
        iconBorder: const Color(0xFFDBEAFE),
        iconBorderWidth: highContrast ? 2 : 1,
        closeBackground: highContrast ? const Color(0xFF020617) : const Color(0xFF111827),
        closeBorder: const Color(0xFFDBEAFE),
        closeBorderWidth: highContrast ? 2 : 1,
      );
    case AppToastState.processing:
      return _ToastPalette(
        background: highContrast ? const Color(0xFF111827) : const Color(0xFF1F2937),
        border: const Color(0xFFF59E0B),
        iconBackground: const Color(0xFF78350F),
        iconColor: const Color(0xFFFDE68A),
        titleColor: Colors.white,
        messageColor: highContrast ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
        closeColor: const Color(0xFFFCD34D),
        borderWidth: highContrast ? 2 : 1.5,
        iconBorder: const Color(0xFFFDE68A),
        iconBorderWidth: highContrast ? 2 : 1,
        closeBackground: highContrast ? const Color(0xFF111827) : const Color(0xFF1F2937),
        closeBorder: const Color(0xFFFCD34D),
        closeBorderWidth: highContrast ? 2 : 1,
      );
    case AppToastState.success:
      return _ToastPalette(
        background: highContrast ? const Color(0xFF052E16) : const Color(0xFF14532D),
        border: const Color(0xFF22C55E),
        iconBackground: const Color(0xFF166534),
        iconColor: const Color(0xFFDCFCE7),
        titleColor: Colors.white,
        messageColor: highContrast ? const Color(0xFFDCFCE7) : const Color(0xFFD1FAE5),
        closeColor: const Color(0xFFBBF7D0),
        borderWidth: highContrast ? 2 : 1.5,
        iconBorder: const Color(0xFFDCFCE7),
        iconBorderWidth: highContrast ? 2 : 1,
        closeBackground: highContrast ? const Color(0xFF052E16) : const Color(0xFF14532D),
        closeBorder: const Color(0xFFBBF7D0),
        closeBorderWidth: highContrast ? 2 : 1,
      );
    case AppToastState.error:
      return _ToastPalette(
        background: highContrast ? const Color(0xFF450A0A) : const Color(0xFF7F1D1D),
        border: const Color(0xFFEF4444),
        iconBackground: const Color(0xFF991B1B),
        iconColor: const Color(0xFFFEE2E2),
        titleColor: Colors.white,
        messageColor: highContrast ? const Color(0xFFFEE2E2) : const Color(0xFFFECACA),
        closeColor: const Color(0xFFFCA5A5),
        borderWidth: highContrast ? 2 : 1.5,
        iconBorder: const Color(0xFFFEE2E2),
        iconBorderWidth: highContrast ? 2 : 1,
        closeBackground: highContrast ? const Color(0xFF450A0A) : const Color(0xFF7F1D1D),
        closeBorder: const Color(0xFFFCA5A5),
        closeBorderWidth: highContrast ? 2 : 1,
      );
    case AppToastState.warning:
      return _ToastPalette(
        background: highContrast ? const Color(0xFF431407) : const Color(0xFF7C2D12),
        border: const Color(0xFFFB923C),
        iconBackground: const Color(0xFF9A3412),
        iconColor: const Color(0xFFFFEDD5),
        titleColor: Colors.white,
        messageColor: highContrast ? const Color(0xFFFFEDD5) : const Color(0xFFFED7AA),
        closeColor: const Color(0xFFFED7AA),
        borderWidth: highContrast ? 2 : 1.5,
        iconBorder: const Color(0xFFFFEDD5),
        iconBorderWidth: highContrast ? 2 : 1,
        closeBackground: highContrast ? const Color(0xFF431407) : const Color(0xFF7C2D12),
        closeBorder: const Color(0xFFFED7AA),
        closeBorderWidth: highContrast ? 2 : 1,
      );
  }
}

class _ToastPalette {
  const _ToastPalette({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
    required this.titleColor,
    required this.messageColor,
    required this.closeColor,
    required this.borderWidth,
    required this.iconBorder,
    required this.iconBorderWidth,
    required this.closeBackground,
    required this.closeBorder,
    required this.closeBorderWidth,
  });

  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
  final Color titleColor;
  final Color messageColor;
  final Color closeColor;
  final double borderWidth;
  final Color iconBorder;
  final double iconBorderWidth;
  final Color closeBackground;
  final Color closeBorder;
  final double closeBorderWidth;
}
