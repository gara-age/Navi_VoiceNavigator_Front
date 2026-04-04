class AppSettings {
  const AppSettings({
    required this.shortcuts,
    required this.security,
    required this.display,
  });

  final ShortcutSettings shortcuts;
  final SecuritySettings security;
  final DisplaySettings display;

  factory AppSettings.defaults() {
    return const AppSettings(
      shortcuts: ShortcutSettings(
        enabled: true,
        listenToggle: 'F2',
        screenRead: 'F3',
        openSettings: 'F4',
      ),
      security: SecuritySettings(
        secureInputMode: false,
      ),
      display: DisplaySettings(
        darkTheme: false,
        largeText: false,
      ),
    );
  }

  AppSettings copyWith({
    ShortcutSettings? shortcuts,
    SecuritySettings? security,
    DisplaySettings? display,
  }) {
    return AppSettings(
      shortcuts: shortcuts ?? this.shortcuts,
      security: security ?? this.security,
      display: display ?? this.display,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shortcuts': shortcuts.toJson(),
      'security': security.toJson(),
      'display': display.toJson(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      shortcuts: ShortcutSettings.fromJson(
        Map<String, dynamic>.from(json['shortcuts'] ?? const {}),
      ),
      security: SecuritySettings.fromJson(
        Map<String, dynamic>.from(json['security'] ?? const {}),
      ),
      display: DisplaySettings.fromJson(
        Map<String, dynamic>.from(json['display'] ?? const {}),
      ),
    );
  }
}

class ShortcutSettings {
  const ShortcutSettings({
    required this.enabled,
    required this.listenToggle,
    required this.screenRead,
    required this.openSettings,
  });

  final bool enabled;
  final String listenToggle;
  final String screenRead;
  final String openSettings;

  ShortcutSettings copyWith({
    bool? enabled,
    String? listenToggle,
    String? screenRead,
    String? openSettings,
  }) {
    return ShortcutSettings(
      enabled: enabled ?? this.enabled,
      listenToggle: listenToggle ?? this.listenToggle,
      screenRead: screenRead ?? this.screenRead,
      openSettings: openSettings ?? this.openSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'listen_toggle': listenToggle,
      'screen_read': screenRead,
      'open_settings': openSettings,
    };
  }

  factory ShortcutSettings.fromJson(Map<String, dynamic> json) {
    return ShortcutSettings(
      enabled: json['enabled'] as bool? ?? true,
      listenToggle: json['listen_toggle'] as String? ?? 'F2',
      screenRead: json['screen_read'] as String? ?? 'F3',
      openSettings: json['open_settings'] as String? ?? 'F4',
    );
  }
}

class SecuritySettings {
  const SecuritySettings({
    required this.secureInputMode,
  });

  final bool secureInputMode;

  SecuritySettings copyWith({
    bool? secureInputMode,
  }) {
    return SecuritySettings(
      secureInputMode: secureInputMode ?? this.secureInputMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'secure_input_mode': secureInputMode,
    };
  }

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      secureInputMode: json['secure_input_mode'] as bool? ?? false,
    );
  }
}

class DisplaySettings {
  const DisplaySettings({
    required this.darkTheme,
    required this.largeText,
  });

  final bool darkTheme;
  final bool largeText;

  DisplaySettings copyWith({
    bool? darkTheme,
    bool? largeText,
  }) {
    return DisplaySettings(
      darkTheme: darkTheme ?? this.darkTheme,
      largeText: largeText ?? this.largeText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dark_theme': darkTheme,
      'large_text': largeText,
    };
  }

  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      darkTheme: json['dark_theme'] as bool? ?? false,
      largeText: json['large_text'] as bool? ?? false,
    );
  }
}
