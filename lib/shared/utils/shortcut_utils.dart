import 'package:flutter/services.dart';

class ShortcutUtils {
  ShortcutUtils._();

  static String normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parts = trimmed
        .split('+')
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '';
    }

    const modifierOrder = ['meta', 'control', 'alt', 'shift'];
    final modifiers = <String>[];
    String? key;

    for (final part in parts) {
      if (modifierOrder.contains(part)) {
        if (!modifiers.contains(part)) {
          modifiers.add(part);
        }
      } else {
        key = part;
      }
    }

    modifiers.sort(
      (a, b) => modifierOrder.indexOf(a).compareTo(modifierOrder.indexOf(b)),
    );

    final ordered = [...modifiers];
    if (key != null) {
      ordered.add(key);
    }

    return ordered.join('+');
  }

  static String? captureFromEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return null;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final parts = <String>[];

    if (pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight)) {
      parts.add('meta');
    }
    if (pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) {
      parts.add('control');
    }
    if (pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight)) {
      parts.add('alt');
    }
    if (pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight)) {
      parts.add('shift');
    }

    final key = _keyLabel(event.logicalKey);
    if (key == null || key.isEmpty) {
      return null;
    }

    parts.add(key.toLowerCase());
    return normalize(parts.join('+'));
  }

  static bool matches(KeyEvent event, String shortcut) {
    final normalized = normalize(shortcut);
    if (normalized.isEmpty) {
      return false;
    }

    final captured = captureFromEvent(event);
    if (captured == null || captured.isEmpty) {
      return false;
    }

    return captured == normalized;
  }

  static String displayLabel(String shortcut) {
    final normalized = normalize(shortcut);
    if (normalized.isEmpty) {
      return '미설정';
    }

    return normalized
        .split('+')
        .map((part) {
          switch (part) {
            case 'meta':
              return 'Cmd';
            case 'control':
              return 'Ctrl';
            case 'alt':
              return 'Alt';
            case 'shift':
              return 'Shift';
            default:
              return part.toUpperCase();
          }
        })
        .join(' + ');
  }

  static String normalizeCommandText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isAffirmativeResponse(String value) {
    final normalized = normalizeCommandText(value);

    return normalized == '응' ||
        normalized == '네' ||
        normalized == '예' ||
        normalized == '좋아' ||
        normalized == '그래' ||
        normalized == '재생해줘' ||
        normalized == '진행해줘' ||
        normalized == '실행해줘';
  }

  static String? _keyLabel(LogicalKeyboardKey key) {
    final label = key.keyLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }

    if (key == LogicalKeyboardKey.space) {
      return 'space';
    }

    final debugName = key.debugName;
    if (debugName == null || debugName.isEmpty) {
      return null;
    }

    if (debugName.startsWith('Key ')) {
      return debugName.replaceFirst('Key ', '');
    }

    if (debugName.startsWith('Digit ')) {
      return debugName.replaceFirst('Digit ', '');
    }

    if (debugName.startsWith('Numpad ')) {
      return debugName.replaceFirst('Numpad ', 'num');
    }

    return debugName.toLowerCase().replaceAll(' ', '_');
  }
}
