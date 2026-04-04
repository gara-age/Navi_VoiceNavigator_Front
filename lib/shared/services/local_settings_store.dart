import 'dart:convert';
import 'dart:io';

import '../models/settings_models.dart';

class LocalSettingsStore {
  LocalSettingsStore._();

  static final LocalSettingsStore instance = LocalSettingsStore._();

  Future<AppSettings> load() async {
    final file = File('${Directory.current.path}/runtime/settings.json');

    if (!await file.exists()) {
      return AppSettings.defaults();
    }

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = File('${Directory.current.path}/runtime/settings.json');
    await file.parent.create(recursive: true);

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      flush: true,
    );
  }
}
