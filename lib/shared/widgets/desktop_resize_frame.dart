import 'dart:io';

import 'package:flutter/material.dart';

import '../services/window_control_service.dart';

class DesktopResizeFrame extends StatelessWidget {
  const DesktopResizeFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return child;
    }

    return Stack(
      children: [
        child,
        ..._buildResizeHandles(),
      ],
    );
  }

  List<Widget> _buildResizeHandles() {
    const edge = 6.0;
    const corner = 12.0;

    return [
      const _ResizeHandle(
        left: 0,
        top: 0,
        right: 0,
        height: edge,
        direction: 'top',
        cursor: SystemMouseCursors.resizeUp,
      ),
      const _ResizeHandle(
        left: 0,
        bottom: 0,
        right: 0,
        height: edge,
        direction: 'bottom',
        cursor: SystemMouseCursors.resizeDown,
      ),
      const _ResizeHandle(
        left: 0,
        top: 0,
        bottom: 0,
        width: edge,
        direction: 'left',
        cursor: SystemMouseCursors.resizeLeft,
      ),
      const _ResizeHandle(
        right: 0,
        top: 0,
        bottom: 0,
        width: edge,
        direction: 'right',
        cursor: SystemMouseCursors.resizeRight,
      ),
      const _ResizeHandle(
        left: 0,
        top: 0,
        width: corner,
        height: corner,
        direction: 'topLeft',
        cursor: SystemMouseCursors.resizeUpLeft,
      ),
      const _ResizeHandle(
        right: 0,
        top: 0,
        width: corner,
        height: corner,
        direction: 'topRight',
        cursor: SystemMouseCursors.resizeUpRight,
      ),
      const _ResizeHandle(
        left: 0,
        bottom: 0,
        width: corner,
        height: corner,
        direction: 'bottomLeft',
        cursor: SystemMouseCursors.resizeDownLeft,
      ),
      const _ResizeHandle(
        right: 0,
        bottom: 0,
        width: corner,
        height: corner,
        direction: 'bottomRight',
        cursor: SystemMouseCursors.resizeDownRight,
      ),
    ];
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required this.direction,
    required this.cursor,
  });

  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;
  final String direction;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        opaque: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) =>
              WindowControlService.instance.startResize(direction),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
