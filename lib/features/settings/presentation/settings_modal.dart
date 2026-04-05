import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/settings_models.dart';
import '../application/settings_controller.dart';

class SettingsModal extends ConsumerStatefulWidget {
  const SettingsModal({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  ConsumerState<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<SettingsModal> {
  static const List<String> _tabs = [
    '기본 설정',
    '단축키',
    '보안',
    '화면 설정',
  ];

  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);

    return Center(
      child: Container(
        width: 820,
        height: 620,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(),
                  Container(
                    width: 1,
                    color: const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildBody(settings, notifier),
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '설정',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '앱 설정과 화면 옵션을 조정합니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 190,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final selected = _selectedTab == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() => _selectedTab = index);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFFEFF6FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    AppSettings settings,
    SettingsController notifier,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildGeneralTab(settings);
      case 1:
        return _buildShortcutsTab(settings, notifier);
      case 2:
        return _buildSecurityTab(settings, notifier);
      case 3:
        return _buildDisplayTab(settings, notifier);
      default:
        return _buildGeneralTab(settings);
    }
  }

  Widget _buildGeneralTab(AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기본 설정',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '앱의 기본 동작에 관련된 항목입니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoTile(
          title: '자동 언어 감지',
          description:
              settings.general.autoLanguageDetection ? '사용 중' : '사용 안 함',
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          title: '마이크 감도',
          description:
              settings.general.microphoneSensitivity.toStringAsFixed(2),
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          title: '음성 속도',
          description: settings.general.ttsSpeed.toStringAsFixed(1),
        ),
      ],
    );
  }

  Widget _buildShortcutsTab(
    AppSettings settings,
    SettingsController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '단축키',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '자주 사용하는 기능의 단축키를 수정합니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: TextEditingController(
            text: settings.shortcuts.listenToggle,
          ),
          decoration: const InputDecoration(
            labelText: '음성 듣기 단축키',
          ),
          onChanged: notifier.setListenToggleShortcut,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: TextEditingController(
            text: settings.shortcuts.screenRead,
          ),
          decoration: const InputDecoration(
            labelText: '화면 읽기 단축키',
          ),
          onChanged: notifier.setScreenReadShortcut,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: TextEditingController(
            text: settings.shortcuts.openSettings,
          ),
          decoration: const InputDecoration(
            labelText: '설정 열기 단축키',
          ),
          onChanged: notifier.setOpenSettingsShortcut,
        ),
      ],
    );
  }

  Widget _buildSecurityTab(
    AppSettings settings,
    SettingsController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '보안',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '민감한 입력과 안내 관련 옵션입니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('보안 입력 모드'),
          subtitle: const Text('민감한 입력 상황에서 읽기와 입력을 제한합니다.'),
          value: settings.security.secureInputMode,
          onChanged: notifier.setSecureMode,
        ),
      ],
    );
  }

  Widget _buildDisplayTab(
    AppSettings settings,
    SettingsController notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '화면 설정',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '테마와 글자 크기 같은 화면 표시 옵션입니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('다크 테마'),
          subtitle: const Text('어두운 배경 테마를 사용합니다.'),
          value: settings.display.darkTheme,
          onChanged: notifier.setDarkTheme,
        ),
                SwitchListTile(
          title: const Text('고대비'),
          subtitle: const Text('명암 대비를 높여 가독성을 향상합니다.'),
          value: settings.display.highContrast,
          onChanged: notifier.setHighContrast,
        ),
        SwitchListTile(
          title: const Text('큰 글씨'),
          subtitle: const Text('앱 전체 텍스트를 더 크게 표시합니다.'),
          value: settings.display.largeText,
          onChanged: notifier.setLargeText,
        ),
      ],
    );
  }

  Widget _buildFooter(SettingsController notifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '변경 후 저장을 누르면 설정 파일에 반영됩니다.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: widget.onClose,
            child: const Text('닫기'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              await notifier.save();
              if (mounted) {
                widget.onClose();
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
