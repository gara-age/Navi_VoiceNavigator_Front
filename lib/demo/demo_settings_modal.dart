import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/app_theme.dart';
import '../shared/models/settings_models.dart';
import '../shared/services/local_ui_state_service.dart';
import '../shared/utils/shortcut_utils.dart';

class DemoSettingsModal extends StatefulWidget {
  const DemoSettingsModal({
    super.key,
    required this.initialSettings,
    required this.onClose,
    required this.onSaved,
    this.onChanged,
  });

  final AppSettings initialSettings;
  final VoidCallback onClose;
  final ValueChanged<AppSettings> onSaved;
  final ValueChanged<AppSettings>? onChanged;

  @override
  State<DemoSettingsModal> createState() => _DemoSettingsModalState();
}

class _DemoSettingsModalState extends State<DemoSettingsModal> {
  static const _tabs = ['기본 설정', '단축키', '보안', '화면 설정'];

  final FocusNode _focusNode = FocusNode(debugLabel: 'demo_settings_modal_focus');
  final ScrollController _bodyScrollController = ScrollController();

  late AppSettings _settings;
  int _selectedTab = 0;
  String? _capturingField;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    LocalUiStateService.instance.setSettingsModalOpen(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    LocalUiStateService.instance.setSettingsModalOpen(false);
    _bodyScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_capturingField != null) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _capturingField = null);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        _setShortcut(_capturingField!, '');
        setState(() => _capturingField = null);
        return KeyEventResult.handled;
      }

      final shortcut = ShortcutUtils.captureFromEvent(event);
      if (shortcut == null || shortcut.isEmpty) {
        return KeyEventResult.handled;
      }

      _setShortcut(_capturingField!, shortcut);
      setState(() => _capturingField = null);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _update(AppSettings next) {
    setState(() => _settings = next);
    widget.onChanged?.call(next);
  }

  void _updateDisplay({
    bool? darkTheme,
    bool? highContrast,
    bool? largeText,
  }) {
    final current = _settings.display;
    var nextDarkTheme = darkTheme ?? current.darkTheme;
    var nextHighContrast = highContrast ?? current.highContrast;
    final nextLargeText = largeText ?? current.largeText;

    if (darkTheme == true) {
      nextHighContrast = false;
    }
    if (highContrast == true) {
      nextDarkTheme = false;
    }

    _update(
      _settings.copyWith(
        display: current.copyWith(
          darkTheme: nextDarkTheme,
          highContrast: nextHighContrast,
          largeText: nextLargeText,
        ),
      ),
    );
  }

  void _selectTab(int value) {
    setState(() => _selectedTab = value);
    if (_bodyScrollController.hasClients) {
      _bodyScrollController.jumpTo(0);
    }
  }

  void _setShortcut(String field, String value) {
    final normalized = ShortcutUtils.normalize(value);
    var shortcuts = _settings.shortcuts;

    if (normalized.isNotEmpty) {
      if (field != 'listen' &&
          ShortcutUtils.normalize(shortcuts.listenToggle) == normalized) {
        shortcuts = shortcuts.copyWith(listenToggle: '');
      }
      if (field != 'screen' &&
          ShortcutUtils.normalize(shortcuts.screenRead) == normalized) {
        shortcuts = shortcuts.copyWith(screenRead: '');
      }
      if (field != 'settings' &&
          ShortcutUtils.normalize(shortcuts.openSettings) == normalized) {
        shortcuts = shortcuts.copyWith(openSettings: '');
      }
    }

    switch (field) {
      case 'listen':
        shortcuts = shortcuts.copyWith(listenToggle: normalized);
        break;
      case 'screen':
        shortcuts = shortcuts.copyWith(screenRead: normalized);
        break;
      case 'settings':
        shortcuts = shortcuts.copyWith(openSettings: normalized);
        break;
    }

    _update(_settings.copyWith(shortcuts: shortcuts));
  }

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Container(
          width: 780,
          height: 620,
          decoration: BoxDecoration(
            color: surfaceTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: surfaceTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              _ModalHeader(
                title: '설정',
                subtitle: '데모 모드 설정과 화면 표시 옵션을 조정합니다.',
                onClose: widget.onClose,
              ),
              Divider(height: 1, color: surfaceTheme.border),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Sidebar(
                      items: _tabs,
                      selectedTab: _selectedTab,
                      onSelect: _selectTab,
                    ),
                    Container(width: 1, color: surfaceTheme.border),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            controller: _bodyScrollController,
                            padding: const EdgeInsets.all(20),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: _buildBody(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: surfaceTheme.contentBackground,
                  border: Border(top: BorderSide(color: surfaceTheme.border)),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Text(
                      _capturingField == null
                          ? '변경 내용은 저장 전에도 바로 데모 화면에 반영됩니다.'
                          : '원하는 키를 누르세요. Delete는 해제, Esc는 취소입니다.',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: surfaceTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    _ModalButton(
                      label: '취소',
                      primary: false,
                      onTap: widget.onClose,
                    ),
                    const SizedBox(width: 10),
                    _ModalButton(
                      label: '저장',
                      primary: true,
                      onTap: () => widget.onSaved(_settings),
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

  Widget _buildBody() {
    switch (_selectedTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('기본 설정'),
            _ToggleCard(
              title: '자동 언어 감지',
              description: '데모 음성 명령의 언어 감지 상태를 표시합니다.',
              value: _settings.general.autoLanguageDetection,
              onChanged: (value) => _update(
                _settings.copyWith(
                  general: _settings.general.copyWith(
                    autoLanguageDetection: value,
                  ),
                ),
              ),
            ),
            _SliderCard(
              title: '마이크 감도',
              description: '데모 시나리오의 음성 반응 강도를 조절합니다.',
              value: _settings.general.microphoneSensitivity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) => _update(
                _settings.copyWith(
                  general: _settings.general.copyWith(
                    microphoneSensitivity: value,
                  ),
                ),
              ),
            ),
            _SliderCard(
              title: '음성 속도',
              description: '안내 음성 재생 속도를 조절합니다.',
              value: _settings.general.ttsSpeed,
              min: 0.5,
              max: 1.5,
              onChanged: (value) => _update(
                _settings.copyWith(
                  general: _settings.general.copyWith(
                    ttsSpeed: value,
                  ),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('단축키'),
            _ShortcutCard(
              title: '음성 듣기',
              value: _settings.shortcuts.listenToggle,
              capturing: _capturingField == 'listen',
              onCapture: () => setState(() => _capturingField = 'listen'),
            ),
            _ShortcutCard(
              title: '현재 화면 읽기',
              value: _settings.shortcuts.screenRead,
              capturing: _capturingField == 'screen',
              onCapture: () => setState(() => _capturingField = 'screen'),
            ),
            _ShortcutCard(
              title: '설정 열기',
              value: _settings.shortcuts.openSettings,
              capturing: _capturingField == 'settings',
              onCapture: () => setState(() => _capturingField = 'settings'),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('보안'),
            _ToggleCard(
              title: '보안 입력 모드',
              description: '민감한 입력 상황에서 읽기와 입력을 제한합니다.',
              value: _settings.security.secureInputMode,
              onChanged: (value) => _update(
                _settings.copyWith(
                  security: _settings.security.copyWith(
                    secureInputMode: value,
                  ),
                ),
              ),
            ),
            _ToggleCard(
              title: '민감한 도메인 경고',
              description: '데모 중 민감한 입력 페이지를 만났을 때 경고를 표시합니다.',
              value: _settings.security.sensitiveDomainAlert,
              onChanged: (value) => _update(
                _settings.copyWith(
                  security: _settings.security.copyWith(
                    sensitiveDomainAlert: value,
                  ),
                ),
              ),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('화면 설정'),
            _ToggleCard(
              title: '다크 테마',
              description: '어두운 테마를 사용합니다.',
              value: _settings.display.darkTheme,
              onChanged: (value) => _updateDisplay(darkTheme: value),
            ),
            _ToggleCard(
              title: '큰 글씨',
              description: '앱 전체 텍스트를 더 크게 표시합니다.',
              value: _settings.display.largeText,
              onChanged: (value) => _updateDisplay(largeText: value),
            ),
            _ToggleCard(
              title: '고대비',
              description: '명암 대비를 높여 가독성을 향상합니다.',
              value: _settings.display.highContrast,
              onChanged: (value) => _updateDisplay(highContrast: value),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: surfaceTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  color: surfaceTheme.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: surfaceTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedTab,
    required this.onSelect,
  });

  final List<String> items;
  final int selectedTab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return SizedBox(
      width: 190,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final selected = selectedTab == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? surfaceTheme.contentBackground : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? surfaceTheme.accent : surfaceTheme.border,
                  ),
                ),
                child: Text(
                  items[index],
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? surfaceTheme.accent : surfaceTheme.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: surfaceTheme.textPrimary,
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaceTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: surfaceTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    height: 1.5,
                    color: surfaceTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaceTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: surfaceTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              height: 1.5,
              color: surfaceTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                color: surfaceTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.value,
    required this.capturing,
    required this.onCapture,
  });

  final String title;
  final String value;
  final bool capturing;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceTheme.contentBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: capturing ? surfaceTheme.accent : surfaceTheme.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: surfaceTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  capturing
                      ? '원하는 키를 누르세요. Delete는 해제, Esc는 취소입니다.'
                      : ShortcutUtils.displayLabel(value),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    height: 1.5,
                    color:
                        capturing ? surfaceTheme.accent : surfaceTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton(
            onPressed: onCapture,
            child: Text(capturing ? '입력 중' : '변경'),
          ),
        ],
      ),
    );
  }
}

class _ModalButton extends StatelessWidget {
  const _ModalButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return ElevatedButton(
        onPressed: onTap,
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
