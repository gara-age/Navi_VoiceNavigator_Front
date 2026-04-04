import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/settings_models.dart';
import '../../../shared/services/local_settings_store.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(AppSettings.defaults());

  Future<void> load() async {
    state = await LocalSettingsStore.instance.load();
  }

  Future<void> save() async {
    await LocalSettingsStore.instance.save(state);
  }

  void setSecureMode(bool value) {
    state = state.copyWith(
      security: state.security.copyWith(secureInputMode: value),
    );
  }

  void setDarkTheme(bool value) {
    state = state.copyWith(
      display: state.display.copyWith(darkTheme: value),
    );
  }

  void setLargeText(bool value) {
    state = state.copyWith(
      display: state.display.copyWith(largeText: value),
    );
  }

  void setListenToggleShortcut(String value) {
    state = state.copyWith(
      shortcuts: state.shortcuts.copyWith(listenToggle: value),
    );
  }

  void setScreenReadShortcut(String value) {
    state = state.copyWith(
      shortcuts: state.shortcuts.copyWith(screenRead: value),
    );
  }

  void setOpenSettingsShortcut(String value) {
    state = state.copyWith(
      shortcuts: state.shortcuts.copyWith(openSettings: value),
    );
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController();
});
