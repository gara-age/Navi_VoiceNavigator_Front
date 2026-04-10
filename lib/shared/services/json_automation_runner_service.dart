import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class JsonAutomationRunnerResult {
  const JsonAutomationRunnerResult({
    required this.success,
    required this.status,
    required this.summary,
    required this.raw,
    this.error,
  });

  final bool success;
  final String status;
  final String summary;
  final Map<String, dynamic> raw;
  final String? error;
}

class JsonAutomationRunnerService {
  JsonAutomationRunnerService._();

  static final JsonAutomationRunnerService instance =
      JsonAutomationRunnerService._();

  static const String _compiledProjectRoot = String.fromEnvironment(
    'VOICE_NAVIGATOR_PROJECT_ROOT',
  );

  Future<JsonAutomationRunnerResult> runPlan({
    required String rawPlan,
  }) async {
    final root = _resolveProjectRoot();
    if (root == null) {
      return const JsonAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: 'JSON 자동화 실행기를 찾지 못했습니다.',
        raw: {'reason': 'root_not_found'},
        error: 'root_not_found',
      );
    }

    late final Map<String, dynamic> decodedPlan;
    try {
      final decoded = jsonDecode(rawPlan);
      if (decoded is! Map<String, dynamic>) {
        return const JsonAutomationRunnerResult(
          success: false,
          status: 'error',
          summary: '자동화 계획 JSON 형식이 올바르지 않습니다.',
          raw: {'reason': 'invalid_json'},
          error: 'invalid_json',
        );
      }
      decodedPlan = decoded;
    } catch (_) {
      return const JsonAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: '자동화 계획 JSON 형식이 올바르지 않습니다.',
        raw: {'reason': 'invalid_json'},
        error: 'invalid_json',
      );
    }

    final invocation = await _prepareInvocation(decodedPlan);
    if (invocation == null) {
      return const JsonAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: '지원하지 않는 자동화 계획입니다.',
        raw: {'reason': 'unsupported_plan'},
        error: 'unsupported_plan',
      );
    }

    final pythonCommand = _resolvePythonCommand(
      root,
      invocation.moduleName,
      invocation.moduleArguments,
    );
    if (pythonCommand == null) {
      return JsonAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: '자동화용 Python 실행기를 찾지 못했습니다.',
        raw: {'reason': 'python_not_found', 'module': invocation.moduleName},
        error: 'python_not_found',
      );
    }

    try {
      debugPrint('Json automation root = ${root.path}');
      debugPrint('Json automation module = ${invocation.moduleName}');
      debugPrint('Json automation executable = ${pythonCommand.executable}');
      debugPrint(
        'Json automation arguments = ${pythonCommand.arguments}',
      );
      return await _runProcess(
        executable: pythonCommand.executable,
        arguments: pythonCommand.arguments,
        workingDirectory: root.path,
        environment: {
          ...Platform.environment,
          'VOICE_NAVIGATOR_ROOT': root.path,
          'PLAYWRIGHT_HEADLESS': 'false',
          'PYTHONUTF8': '1',
          'PYTHONHOME': '',
          'PYTHONPATH': '',
        },
      );
    } finally {
      await invocation.dispose();
    }
  }

  Future<JsonAutomationRunnerResult> _runProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    Map<String, dynamic>? resultPayload;

    Future<void> handleStdoutLine(String line) async {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        return;
      }
      stdoutBuffer.writeln(trimmed);

      try {
        final envelope = jsonDecode(trimmed) as Map<String, dynamic>;
        final kind = envelope['kind'] as String? ?? '';
        if (kind == 'progress') {
          final payload = Map<String, dynamic>.from(
            envelope['payload'] as Map? ?? const <String, dynamic>{},
          );
          debugPrint('Json automation progress = ${jsonEncode(payload)}');
          return;
        }
        if (kind != 'result') {
          return;
        }

        resultPayload = Map<String, dynamic>.from(
          envelope['payload'] as Map? ?? const <String, dynamic>{},
        );
        debugPrint('Json automation result = ${jsonEncode(resultPayload)}');
      } catch (_) {
        debugPrint('Json automation stdout line = $trimmed');
      }
    }

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          handleStdoutLine,
          onDone: () {
            if (!stdoutDone.isCompleted) {
              stdoutDone.complete();
            }
          },
        );

    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty) {
              stderrBuffer.writeln(trimmed);
            }
          },
          onDone: () {
            if (!stderrDone.isCompleted) {
              stderrDone.complete();
            }
          },
        );

    final exitCode = await process.exitCode;
    await Future.wait<void>([
      stdoutDone.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      ),
      stderrDone.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      ),
    ]);

    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (exitCode != 0) {
      final detail = stderrBuffer.isNotEmpty
          ? stderrBuffer.toString().trim()
          : stdoutBuffer.toString().trim();
      debugPrint('Json automation exitCode = $exitCode');
      if (stdoutBuffer.isNotEmpty) {
        debugPrint('Json automation stdout = ${stdoutBuffer.toString()}');
      }
      if (stderrBuffer.isNotEmpty) {
        debugPrint('Json automation stderr = ${stderrBuffer.toString()}');
      }
      final detailLine = _firstMeaningfulLine(detail);
      return JsonAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: detailLine == null
            ? 'JSON 자동화 실행이 비정상 종료되었습니다.'
            : 'JSON 자동화 실행이 비정상 종료되었습니다. $detailLine',
        raw: {
          'exit_code': exitCode,
          'stdout': stdoutBuffer.toString(),
          'stderr': stderrBuffer.toString(),
        },
        error: detail.isEmpty ? 'process_exit_$exitCode' : detail,
      );
    }

    if (resultPayload == null) {
      debugPrint('Json automation missing result payload');
      if (stdoutBuffer.isNotEmpty) {
        debugPrint('Json automation stdout = ${stdoutBuffer.toString()}');
      }
      if (stderrBuffer.isNotEmpty) {
        debugPrint('Json automation stderr = ${stderrBuffer.toString()}');
      }
      return JsonAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: '자동화 실행 결과를 받지 못했습니다.',
        raw: {
          'stdout': stdoutBuffer.toString(),
          'stderr': stderrBuffer.toString(),
        },
        error: 'missing_result_payload',
      );
    }

    final isSuccess = resultPayload!['status'] == 'success';
    final summary = _resolveSummary(resultPayload!);
    final reason = (resultPayload!['reason'] as String?)?.trim();

    return JsonAutomationRunnerResult(
      success: isSuccess,
      status: resultPayload!['status'] as String? ?? 'unknown',
      summary: isSuccess
          ? (summary ?? 'JSON 자동화 계획을 실행했습니다.')
          : _friendlyFailureReason(reason, stdoutBuffer, stderrBuffer),
      raw: resultPayload!,
      error: reason,
    );
  }

  String? _resolveSummary(Map<String, dynamic> payload) {
    final routeSummary = (payload['route_summary'] as String?)?.trim();
    if (routeSummary != null && routeSummary.isNotEmpty) {
      return routeSummary;
    }

    final summary = (payload['summary'] as String?)?.trim();
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }

    final steps = payload['steps'];
    if (steps is List) {
      for (final item in steps.reversed) {
        if (item is! Map) {
          continue;
        }
        final detail = item['detail']?.toString().trim();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
      }
    }

    return null;
  }

  Future<_AutomationInvocation?> _prepareInvocation(
    Map<String, dynamic> rawPlan,
  ) async {
    final rawSteps = rawPlan['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      return null;
    }

    final normalizedPlan = jsonEncode(_normalizePlan(rawPlan));
    final tempDir = await Directory.systemTemp.createTemp(
      'voice_navigator_plan_',
    );
    final planFile = File(
      '${tempDir.path}${Platform.pathSeparator}agent_plan.json',
    );
    await planFile.writeAsString(normalizedPlan, flush: true);

    return _AutomationInvocation(
      moduleName: 'local_server.app.simulation.json_agent_scenario',
      moduleArguments: [planFile.path],
      onDispose: () async {
        if (planFile.existsSync()) {
          await planFile.delete();
        }
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      },
    );
  }

  Map<String, dynamic> _normalizePlan(Map<String, dynamic> rawPlan) {
    final rawSteps = rawPlan['steps'];
    if (rawSteps is! List) {
      return rawPlan;
    }

    final site = rawPlan['site']?.toString().trim() ?? '';
    Map<String, dynamic>? lastTarget;
    final normalizedSteps = <Map<String, dynamic>>[];

    for (final step in rawSteps) {
      if (step is! Map) {
        continue;
      }

      final normalizedStep = Map<String, dynamic>.from(
        step.cast<String, dynamic>(),
      );
      final target = _extractTarget(normalizedStep);
      if (target != null) {
        final normalizedTarget = _normalizeTarget(
          site: site,
          stepType:
              (normalizedStep['type'] ?? normalizedStep['action'])?.toString(),
          target: target,
        );
        normalizedStep['target'] = normalizedTarget;
        lastTarget = normalizedTarget;
      }

      final stepType =
          (normalizedStep['type'] ?? normalizedStep['action'])?.toString();

      if (stepType == 'fill' &&
          normalizedStep['target'] is Map<String, dynamic> &&
          _shouldInsertWaitFor(site, normalizedStep['target'] as Map<String, dynamic>)) {
        normalizedSteps.add({
          'step': _syntheticStepNumber(normalizedStep['step'], normalizedSteps.length),
          'type': 'wait_for',
          'target': normalizedStep['target'],
          'args': {
            'timeout_ms': 4000,
            'state': 'visible',
          },
        });
      }

      if (stepType == 'press' && target == null && lastTarget != null) {
        normalizedStep['target'] = {
          ...lastTarget,
          'reuse_previous_target': true,
        };
      }

      normalizedSteps.add(normalizedStep);
    }

    return {
      ...rawPlan,
      'steps': normalizedSteps,
    };
  }

  Map<String, dynamic> _normalizeTarget({
    required String site,
    required String? stepType,
    required Map<String, dynamic> target,
  }) {
    if (stepType != 'fill') {
      return target;
    }

    final description = target['description']?.toString() ?? '';
    final fallbacks = <Map<String, dynamic>>[];
    final rawFallbacks = target['fallbacks'];
    if (rawFallbacks is List) {
      for (final item in rawFallbacks) {
        if (item is Map) {
          fallbacks.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
        }
      }
    }

    void addFallback(Map<String, dynamic> fallback) {
      final encoded = jsonEncode(fallback);
      if (fallbacks.any((item) => jsonEncode(item) == encoded)) {
        return;
      }
      fallbacks.add(fallback);
    }

    if (site.contains('youtube.com') &&
        description.contains('유튜브') &&
        description.contains('검색')) {
      addFallback({'css': 'input[name="search_query"]'});
      addFallback({'css': 'input[placeholder="검색"]'});
      addFallback({'css': 'input.ytSearchboxComponentInput'});
      addFallback({'css': 'input.yt-searchbox-input'});
    }

    if (site.contains('map.naver.com')) {
      if (description.contains('출발지')) {
        addFallback({'css': 'input[placeholder*="출발지"]'});
        addFallback({'css': 'input[placeholder="출발지 입력"]'});
        addFallback({'css': 'input.input_search[placeholder*="출발지"]'});
        addFallback({'css': '[data-area-directions="departure"] input'});
      }
      if (description.contains('도착지')) {
        addFallback({'css': 'input[placeholder*="도착지"]'});
        addFallback({'css': 'input[placeholder="도착지 입력"]'});
        addFallback({'css': 'input.input_search[placeholder*="도착지"]'});
        addFallback({'css': '[data-area-directions="arrival"] input'});
      }
    }

    if (fallbacks.isEmpty) {
      return target;
    }

    return {
      ...target,
      'fallbacks': fallbacks,
    };
  }

  bool _shouldInsertWaitFor(String site, Map<String, dynamic> target) {
    if (!site.contains('map.naver.com')) {
      return false;
    }
    final description = target['description']?.toString() ?? '';
    return description.contains('출발지') || description.contains('도착지');
  }

  int _syntheticStepNumber(Object? originalStep, int currentLength) {
    if (originalStep is int) {
      return originalStep * 10;
    }
    return (currentLength + 1) * 10;
  }

  Map<String, dynamic>? _extractTarget(Map<String, dynamic> step) {
    final target = step['target'];
    if (target is Map) {
      return Map<String, dynamic>.from(target.cast<String, dynamic>());
    }

    final element = step['element'];
    if (element is String && element.trim().isNotEmpty) {
      return {
        'description': step['description'] ?? '직접 지정 요소',
        'fallbacks': [
          {'css': element.trim()},
        ],
        'frame_scope': 'all_frames',
        'index': 0,
      };
    }

    return null;
  }

  String? _firstMeaningfulLine(String? value) {
    if (value == null) {
      return null;
    }

    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return null;
    }

    return lines.first;
  }

  String _friendlyFailureReason(
    String? reason,
    StringBuffer stdoutBuffer,
    StringBuffer stderrBuffer,
  ) {
    switch (reason) {
      case 'python_not_found':
        return '자동화용 Python 실행기를 찾지 못했습니다.';
      case 'root_not_found':
        return '현재 프로젝트의 자동화 루트를 찾지 못했습니다.';
      case 'plan_file_not_found':
        return '자동화 계획 파일을 찾지 못했습니다.';
      case 'unsupported_platform':
        return '현재 운영체제에서 지원하지 않는 자동화 시나리오입니다.';
      case 'accessibility_permission_required':
        return '운영체제 접근성 권한이 필요합니다.';
      case null:
      case '':
        final detail = stderrBuffer.toString().trim().isNotEmpty
            ? stderrBuffer.toString().trim()
            : stdoutBuffer.toString().trim();
        return detail.isEmpty ? '자동화 실행 중 오류가 발생했습니다.' : detail;
      default:
        return reason;
    }
  }

  _PythonCommand? _resolvePythonCommand(
    Directory root,
    String moduleName,
    List<String> moduleArguments,
  ) {
    final projectRoot = root.path;
    final candidates = <_PythonCommand>[
      _PythonCommand(
        executable:
            '$projectRoot${Platform.pathSeparator}.venv-server${Platform.pathSeparator}bin${Platform.pathSeparator}python',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable:
            '$projectRoot${Platform.pathSeparator}.venv-server${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable: 'python3',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable: 'python',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable: 'py',
        arguments: ['-3', '-m', moduleName, ...moduleArguments],
      ),
    ];

    for (final candidate in candidates) {
      if (_canExecute(candidate.executable)) {
        return candidate;
      }
    }
    return null;
  }

  Directory? _resolveProjectRoot() {
    final root = _resolveCurrentProjectRoot();
    if (root == null) {
      return null;
    }
    return _containsJsonScenario(root) ? root : null;
  }

  Directory? _resolveCurrentProjectRoot() {
    if (_compiledProjectRoot.isNotEmpty) {
      final compiledRoot = Directory(_compiledProjectRoot);
      if (_isFlutterProjectRoot(compiledRoot)) {
        return compiledRoot;
      }
    }

    Directory? findFlutterRoot(String startPath) {
      var dir = Directory(startPath);
      for (var i = 0; i < 14; i++) {
        if (_isFlutterProjectRoot(dir)) {
          return dir;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) {
          break;
        }
        dir = parent;
      }
      return null;
    }

    return findFlutterRoot(Directory.current.path) ??
        findFlutterRoot(File(Platform.resolvedExecutable).parent.path);
  }

  bool _isFlutterProjectRoot(Directory root) {
    if (!root.existsSync()) {
      return false;
    }
    final pubspec = File(
      '${root.path}${Platform.pathSeparator}pubspec.yaml',
    );
    return pubspec.existsSync();
  }

  bool _containsJsonScenario(Directory root) {
    if (!root.existsSync()) {
      return false;
    }
    final scenarioFile = File(
      '${root.path}${Platform.pathSeparator}local_server'
      '${Platform.pathSeparator}app${Platform.pathSeparator}simulation'
      '${Platform.pathSeparator}json_agent_scenario.py',
    );
    return scenarioFile.existsSync();
  }

  bool _canExecute(String executable) {
    if (executable.contains(Platform.pathSeparator)) {
      return File(executable).existsSync();
    }
    return true;
  }
}

class _PythonCommand {
  const _PythonCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

class _AutomationInvocation {
  const _AutomationInvocation({
    required this.moduleName,
    required this.moduleArguments,
    this.onDispose,
  });

  final String moduleName;
  final List<String> moduleArguments;
  final Future<void> Function()? onDispose;

  Future<void> dispose() async {
    await onDispose?.call();
  }
}
