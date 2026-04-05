class AppSettings {
  const AppSettings({
    required this.general,
    required this.shortcuts,
    required this.security,
    required this.display,
  });

  final GeneralSettings general;
  final ShortcutSettings shortcuts;
  final SecuritySettings security;
  final DisplaySettings display;

  factory AppSettings.defaults() {
    return const AppSettings(
      general: GeneralSettings(
        autoLanguageDetection: true,
        microphoneSensitivity: 0.72,
        ttsSpeed: 1.0,
        voiceType: 'ko-KR-Neural2-A',
        autoErrorLogUpload: false,
      ),
      shortcuts: ShortcutSettings(
        enabled: true,
        listenToggle: 'F2',
        screenRead: 'F3',
        openSettings: 'F4',
      ),
      security: SecuritySettings(
        secureInputMode: false,
        sensitiveDomainAlert: true,
      ),
      display: DisplaySettings(
        darkTheme: false,
        highContrast: false,
        largeText: false,
      ),
    );
  }

  AppSettings copyWith({
    GeneralSettings? general,
    ShortcutSettings? shortcuts,
    SecuritySettings? security,
    DisplaySettings? display,
  }) {
    return AppSettings(
      general: general ?? this.general,
      shortcuts: shortcuts ?? this.shortcuts,
      security: security ?? this.security,
      display: display ?? this.display,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'general': general.toJson(),
      'shortcuts': shortcuts.toJson(),
      'security': security.toJson(),
      'display': display.toJson(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      general: GeneralSettings.fromJson(
        Map<String, dynamic>.from(json['general'] ?? const {}),
      ),
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

class GeneralSettings {
  const GeneralSettings({
    required this.autoLanguageDetection,
    required this.microphoneSensitivity,
    required this.ttsSpeed,
    required this.voiceType,
    required this.autoErrorLogUpload,
  });

  final bool autoLanguageDetection;
  final double microphoneSensitivity;
  final double ttsSpeed;
  final String voiceType;
  final bool autoErrorLogUpload;

  GeneralSettings copyWith({
    bool? autoLanguageDetection,
    double? microphoneSensitivity,
    double? ttsSpeed,
    String? voiceType,
    bool? autoErrorLogUpload,
  }) {
    return GeneralSettings(
      autoLanguageDetection:
          autoLanguageDetection ?? this.autoLanguageDetection,
      microphoneSensitivity:
          microphoneSensitivity ?? this.microphoneSensitivity,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      voiceType: voiceType ?? this.voiceType,
      autoErrorLogUpload: autoErrorLogUpload ?? this.autoErrorLogUpload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_language_detection': autoLanguageDetection,
      'microphone_sensitivity': microphoneSensitivity,
      'tts_speed': ttsSpeed,
      'voice_type': voiceType,
      'auto_error_log_upload': autoErrorLogUpload,
    };
  }

  factory GeneralSettings.fromJson(Map<String, dynamic> json) {
    return GeneralSettings(
      autoLanguageDetection:
          json['auto_language_detection'] as bool? ?? true,
      microphoneSensitivity:
          (json['microphone_sensitivity'] as num?)?.toDouble() ?? 0.72,
      ttsSpeed: (json['tts_speed'] as num?)?.toDouble() ?? 1.0,
      voiceType: json['voice_type'] as String? ?? 'ko-KR-Neural2-A',
      autoErrorLogUpload: json['auto_error_log_upload'] as bool? ?? false,
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
    required this.sensitiveDomainAlert,
  });

  final bool secureInputMode;
  final bool sensitiveDomainAlert;

  SecuritySettings copyWith({
    bool? secureInputMode,
    bool? sensitiveDomainAlert,
  }) {
    return SecuritySettings(
      secureInputMode: secureInputMode ?? this.secureInputMode,
      sensitiveDomainAlert:
          sensitiveDomainAlert ?? this.sensitiveDomainAlert,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'secure_input_mode': secureInputMode,
      'sensitive_domain_alert': sensitiveDomainAlert,
    };
  }

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      secureInputMode: json['secure_input_mode'] as bool? ?? false,
      sensitiveDomainAlert:
          json['sensitive_domain_alert'] as bool? ?? true,
    );
  }
}

class DisplaySettings {
  const DisplaySettings({
    required this.darkTheme,
    required this.highContrast,
    required this.largeText,
  });

  final bool darkTheme;
  final bool highContrast;
  final bool largeText;

  DisplaySettings copyWith({
    bool? darkTheme,
    bool? highContrast,
    bool? largeText,
  }) {
    return DisplaySettings(
      darkTheme: darkTheme ?? this.darkTheme,
      highContrast: highContrast ?? this.highContrast,
      largeText: largeText ?? this.largeText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dark_theme': darkTheme,
      'high_contrast': highContrast,
      'large_text': largeText,
    };
  }

  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      darkTheme: json['dark_theme'] as bool? ?? false,
      highContrast: json['high_contrast'] as bool? ?? false,
      largeText: json['large_text'] as bool? ?? false,
    );
  }
}
