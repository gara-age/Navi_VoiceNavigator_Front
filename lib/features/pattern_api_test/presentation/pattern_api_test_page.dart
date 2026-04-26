import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../../../app/theme/colors.dart';
import '../../../../shared/models/agent_api_models.dart';
import '../../../../shared/services/json_automation_runner_service.dart';
import '../../../../shared/services/pattern_automation_runner_service.dart';
import '../../../../shared/widgets/desktop_resize_frame.dart';
import '../../home/presentation/widgets/title_bar.dart';

const _defaultPatternApiUrl = String.fromEnvironment('PATTERN_AGENT_API_URL');

class PatternApiTestPage extends StatefulWidget {
  const PatternApiTestPage({super.key});

  @override
  State<PatternApiTestPage> createState() => _PatternApiTestPageState();
}

class _PatternApiTestPageState extends State<PatternApiTestPage> {
  late final TextEditingController _endpointController;
  late final TextEditingController _instructionController;
  late final TextEditingController _ruleController;

  bool _isSending = false;
  bool _allowInsecureTls = false;
  int? _statusCode;
  String? _responseKind;
  String? _resultSummary;
  String? _errorText;
  String _rawResponse = '';
  String _rawExecution = '';

  List<String> get _rules => _ruleController.text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  Map<String, dynamic> get _requestPreview => {
        'instruction': _instructionController.text.trim(),
        'prompt': {
          'rule': _rules,
        },
      };

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: _defaultPatternApiUrl);
    _instructionController = TextEditingController(
      text: '네이버 지도로 송내역에서 서울역 가는 경로 알려줘',
    );
    _ruleController = TextEditingController(
      text: [
        '사용자 요청을 Pattern Task JSON으로 반환해.',
        'CSS selector, XPath, Playwright 코드는 생성하지 마.',
        'JSON만 반환해.',
        'task_type, slots, risk_level, confidence, host_bias만 필요한 범위에서 채워.',
      ].join('\n'),
    );
    _endpointController.addListener(_handleDraftChanged);
    _instructionController.addListener(_handleDraftChanged);
    _ruleController.addListener(_handleDraftChanged);
  }

  @override
  void dispose() {
    _endpointController.removeListener(_handleDraftChanged);
    _instructionController.removeListener(_handleDraftChanged);
    _ruleController.removeListener(_handleDraftChanged);
    _endpointController.dispose();
    _instructionController.dispose();
    _ruleController.dispose();
    super.dispose();
  }

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final endpoint = _endpointController.text.trim();
    final instruction = _instructionController.text.trim();
    final rules = _rules;

    if (endpoint.isEmpty || instruction.isEmpty || rules.isEmpty) {
      setState(() {
        _errorText = 'endpoint, instruction, rule을 모두 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _statusCode = null;
      _responseKind = null;
      _resultSummary = null;
      _errorText = null;
      _rawResponse = '';
      _rawExecution = '';
    });

    try {
      final uri = Uri.parse(endpoint);
      final requestBody = {
        'instruction': instruction,
        'prompt': {
          'rule': rules,
        },
      };
      final client = _buildClient();

      late final http.Response response;
      try {
        response = await client
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 60));
      } finally {
        client.close();
      }

      final responseBody = response.body;
      final parsed = AgentApiResponseEnvelope.parse(responseBody);
      String? summary;
      String? rawExecution;
      String responseKind;

      switch (parsed.kind) {
        case AgentApiAutomationKind.patternTask:
          responseKind = 'pattern_task';
          if (parsed.patternTask != null) {
            final execution =
                await PatternAutomationRunnerService.instance.runTask(
              rawTask: jsonEncode(parsed.patternTask!.toJson()),
            );
            summary = execution.summary;
            rawExecution = JsonEncoder.withIndent('  ').convert(execution.raw);
          }
          break;
        case AgentApiAutomationKind.legacyPlan:
          responseKind = 'legacy_plan';
          if (parsed.legacyPlan != null) {
            final execution = await JsonAutomationRunnerService.instance.runPlan(
              rawPlan: jsonEncode(parsed.legacyPlan!.raw),
            );
            summary = execution.summary;
            rawExecution = JsonEncoder.withIndent('  ').convert(execution.raw);
          }
          break;
        case AgentApiAutomationKind.message:
          responseKind = 'message';
          summary = parsed.message?.summary;
          break;
      }

      setState(() {
        _statusCode = response.statusCode;
        _responseKind = responseKind;
        _resultSummary = summary;
        _rawResponse = _prettyJsonOrRaw(responseBody);
        _rawExecution = rawExecution ?? '';
        if (response.statusCode < 200 || response.statusCode >= 300) {
          _errorText = 'API 요청이 실패했습니다. (${response.statusCode})';
        }
      });
    } on HandshakeException {
      setState(() {
        _errorText =
            'TLS handshake에 실패했습니다. 개발용 인증서 서버라면 "insecure TLS 허용"을 켜고 다시 시도해 주세요.';
      });
    } catch (error) {
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _prettyJsonOrRaw(String value) {
    try {
      final decoded = jsonDecode(value);
      return JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return value;
    }
  }

  http.Client _buildClient() {
    if (!_allowInsecureTls) {
      return http.Client();
    }

    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  @override
  Widget build(BuildContext context) {
    return DesktopResizeFrame(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const AppTitleBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionCard(
                            title: '요청 입력',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LabeledField(
                                  label: 'Endpoint',
                                  child: TextField(
                                    controller: _endpointController,
                                    decoration: const InputDecoration(
                                      hintText: 'https://your-api.example.com/path',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _LabeledField(
                                  label: 'Instruction',
                                  child: TextField(
                                    controller: _instructionController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      hintText: '사용자 명령을 입력해 주세요.',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _LabeledField(
                                  label: 'Prompt.rule',
                                  child: TextField(
                                    controller: _ruleController,
                                    maxLines: 8,
                                    decoration: const InputDecoration(
                                      hintText:
                                          '규칙을 한 줄에 하나씩 입력해 주세요.',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '각 줄이 prompt.rule 배열의 한 항목으로 전송됩니다.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _allowInsecureTls,
                                  onChanged: (value) {
                                    setState(() {
                                      _allowInsecureTls = value;
                                    });
                                  },
                                  title: const Text('insecure TLS 허용'),
                                  subtitle: const Text(
                                    '개발용 self-signed 인증서 서버 테스트용입니다.',
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: _isSending ? null : _submit,
                                    icon: _isSending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send_rounded),
                                    label: Text(
                                      _isSending ? '전송 중...' : '전송 및 실행 테스트',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: '요청 JSON',
                            child: _CodeBlock(
                              content:
                                  JsonEncoder.withIndent('  ').convert(_requestPreview),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: '결과 요약',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _KeyValue(
                                  label: 'HTTP 상태',
                                  value: _statusCode?.toString() ?? '-',
                                ),
                                _KeyValue(
                                  label: '응답 종류',
                                  value: _responseKind ?? '-',
                                ),
                                _KeyValue(
                                  label: '요약',
                                  value: _resultSummary ?? '-',
                                ),
                                if (_errorText != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorText!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'API 원본 응답',
                            child: _CodeBlock(
                              content:
                                  _rawResponse.isEmpty ? '(아직 응답 없음)' : _rawResponse,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: '자동화 실행 결과',
                            child: _CodeBlock(
                              content: _rawExecution.isEmpty
                                  ? '(아직 실행 결과 없음)'
                                  : _rawExecution,
                            ),
                          ),
                        ],
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'Consolas',
          fontSize: 13,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
