import 'dart:convert';
import 'dart:io';

class LocalBackgroundEventService {
  LocalBackgroundEventService._();

  static final LocalBackgroundEventService instance =
      LocalBackgroundEventService._();

  Future<String?> pollEvent() async {
    final file = await _resolveEventFile();
    if (file == null || !await file.exists()) {
      return null;
    }

    try {
      final raw = await file.readAsString();
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        await clearEvent();
        return null;
      }

      final type = decoded['type']?.toString().trim();
      if (type == null || type.isEmpty) {
        await clearEvent();
        return null;
      }

      await clearEvent();
      return type;
    } catch (_) {
      await clearEvent();
      return null;
    }
  }

  Future<void> clearEvent() async {
    final file = await _resolveEventFile();
    if (file == null) {
      return;
    }

    try {
      await file.parent.create(recursive: true);
      await file.writeAsString('');
    } catch (_) {
      // Ignore local event cleanup failures.
    }
  }

  Future<File?> _resolveEventFile() async {
    final envRoot = Platform.environment['VOICE_NAVIGATOR_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      return File(
        '$envRoot${Platform.pathSeparator}runtime${Platform.pathSeparator}background_event.json',
      );
    }

    final roots = <Directory>[];

    void addAncestors(Directory directory) {
      var current = directory;
      for (var i = 0; i < 8; i++) {
        roots.add(current);
        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }

    addAncestors(Directory.current);
    addAncestors(File(Platform.resolvedExecutable).parent);

    for (final root in roots) {
      final runtimeDir = Directory(
        '${root.path}${Platform.pathSeparator}runtime',
      );
      if (runtimeDir.existsSync()) {
        return File(
          '${runtimeDir.path}${Platform.pathSeparator}background_event.json',
        );
      }
    }

    final fallbackRuntimeDir = Directory(
      '${Directory.current.path}${Platform.pathSeparator}runtime',
    );
    return File(
      '${fallbackRuntimeDir.path}${Platform.pathSeparator}background_event.json',
    );
  }
}
