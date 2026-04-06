import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../shared/models/response_models.dart';

const _unset = Object();
const _agentApiBaseUrl = String.fromEnvironment('AGENT_API_BASE_URL'); 
//실제에서는 'http://127.0.0.1:8000';이런식으로 하면 http://127.0.0.1:8000/agent/respond 로 요청이됨

class SessionUiState {
  const SessionUiState({
    this.lastSummary,
    this.lastFollowUp,
    this.pendingAction,
    this.pendingTarget,
    this.isBusy = false,
    this.isRecording = false,
  });

  final String? lastSummary;
  final String? lastFollowUp;
  final String? pendingAction;
  final String? pendingTarget;
  final bool isBusy;
  final bool isRecording;

  SessionUiState copyWith({
    Object? lastSummary = _unset,
    Object? lastFollowUp = _unset,
    Object? pendingAction = _unset,
    Object? pendingTarget = _unset,
    bool? isBusy,
    bool? isRecording,
  }) {
    return SessionUiState(
      lastSummary: identical(lastSummary, _unset)
          ? this.lastSummary
          : lastSummary as String?,
      lastFollowUp: identical(lastFollowUp, _unset)
          ? this.lastFollowUp
          : lastFollowUp as String?,
      pendingAction: identical(pendingAction, _unset)
          ? this.pendingAction
          : pendingAction as String?,
      pendingTarget: identical(pendingTarget, _unset)
          ? this.pendingTarget
          : pendingTarget as String?,
      isBusy: isBusy ?? this.isBusy,
      isRecording: isRecording ?? this.isRecording,
    );
  }
}

class SessionController extends StateNotifier<SessionUiState> {
  SessionController() : super(const SessionUiState());

  bool hasPendingFollowUp() {
    return _cleanText(state.lastFollowUp) != null &&
        _cleanText(state.pendingAction) != null;
  }

  Future<CommandResponseModel> submitTextCommand(String text) async {
    state = state.copyWith(isBusy: true);

    final payload = await _requestAgentResponse(
      command: text,
      source: 'text',
    );

    final response = _mapAgentPayloadToCommandResponse(
      payload,
      fallbackTranscript: text,
      fallbackSummary: '텍스트 명령을 처리했습니다.',
    );

    _applyResponse(response);
    return response;
  }

  Future<CommandResponseModel> submitFollowUpResponse(String text) async {
    state = state.copyWith(isBusy: true);

    final payload = await _requestAgentResponse(
      command: text,
      source: 'text',
    );

    final response = _mapAgentPayloadToCommandResponse(
      payload,
      fallbackTranscript: text,
      fallbackSummary: '후속 응답을 처리했습니다.',
    );

    _applyResponse(response);
    return response;
  }

  Future<void> startListening() async {
    state = state.copyWith(isRecording: true);
  }

  Future<CommandResponseModel> stopListeningAndProcess() async {
    state = state.copyWith(isRecording: false, isBusy: true);

    const transcript = '음성 인식 결과 텍스트';

    final payload = await _requestAgentResponse(
      command: transcript,
      source: 'voice',
    );

    final response = _mapAgentPayloadToCommandResponse(
      payload,
      fallbackTranscript: transcript,
      fallbackSummary: '음성 명령을 처리했습니다.',
    );

    _applyResponse(response);
    return response;
  }

  Future<CommandResponseModel> triggerScreenRead() async {
    state = state.copyWith(isBusy: true);

    const command = 'screen_read';

    final payload = await _requestAgentResponse(
      command: command,
      source: 'screen_read',
    );

    final response = _mapAgentPayloadToCommandResponse(
      payload,
      fallbackTranscript: command,
      fallbackSummary: '현재 화면을 읽었습니다.',
    );

    _applyResponse(response);
    return response;
  }

  void _applyResponse(CommandResponseModel response) {
    final clearsPending = response.completesFollowUp;

    state = state.copyWith(
      isBusy: false,
      lastSummary: response.summary,
      lastFollowUp: response.followUp,
      pendingAction: clearsPending ? null : response.pendingAction,
      pendingTarget: clearsPending ? null : response.pendingTarget,
    );
  }

  Future<AgentCommandPayload> _requestAgentResponse({
    required String command,
    required String source,
  }) async {
    if (_agentApiBaseUrl.isEmpty) {
      return AgentCommandPayload(
        transcript: command,
        summary: 'Agent 서버 주소가 아직 설정되지 않아 명령을 처리할 수 없습니다.',
        followUp: 'API 서버 주소를 설정한 뒤 다시 시도할까요?',
        isError: true,
        status: 'error',
        completesFollowUp: true,
        rawText: 'Missing AGENT_API_BASE_URL',
      );
    }

    final uri = Uri.parse('$_agentApiBaseUrl/agent/respond');

    try {
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(_buildRequestBody(
              command: command,
              source: source,
            )),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AgentCommandPayload(
          transcript: command,
          summary: 'Agent 서버 요청에 실패했습니다. (${response.statusCode})',
          followUp: '서버 상태를 확인한 뒤 다시 시도할까요?',
          isError: true,
          status: 'error',
          completesFollowUp: true,
          rawText: response.body,
        );
      }

      return _parseAgentResponse(response.body);
    } catch (error) {
      return AgentCommandPayload(
        transcript: command,
        summary: 'Agent 서버에 연결하지 못했습니다.',
        followUp: '네트워크 또는 API 주소를 확인한 뒤 다시 시도할까요?',
        isError: true,
        status: 'error',
        completesFollowUp: true,
        rawText: error.toString(),
      );
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required String command,
    required String source,
  }) {
    return {
      'command': command,
      'source': source, //명령방식 (키보드, 음성, 화면읽기)
      'context': {
        'last_summary': state.lastSummary, //이전 요약
        'last_follow_up': state.lastFollowUp, //이전 후속질문
        'pending_action': state.pendingAction, //보류중인 액션
        'pending_target': state.pendingTarget, //보류중인 타겟
      },
    };
  }

  AgentCommandPayload _parseAgentResponse(String rawResponse) {
    try {
      final decoded = jsonDecode(rawResponse);
      if (decoded is Map<String, dynamic>) {
        return AgentCommandPayload.fromJson(decoded);
      }
      if (decoded is Map) {
        return AgentCommandPayload.fromJson(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    } catch (_) {
      // Fall back to raw text extraction below.
    }

    return AgentCommandPayload(rawText: rawResponse);
  }

  CommandResponseModel _mapAgentPayloadToCommandResponse(
    AgentCommandPayload payload, {
    required String fallbackTranscript,
    required String fallbackSummary,
  }) {
    final transcript = _cleanText(payload.transcript) ?? fallbackTranscript;
    final summary = _cleanText(payload.summary) ??
        _extractSummaryFromRaw(payload.rawText) ??
        fallbackSummary;
    final followUp = _cleanText(payload.followUp);
    final pendingAction = _cleanText(payload.pendingAction);
    final pendingTarget = _cleanText(payload.pendingTarget);
    final status = _resolveStatus(payload);
    final completesFollowUp = payload.completesFollowUp ?? false;

    return CommandResponseModel(
      transcript: transcript,
      summary: summary,
      followUp: followUp,
      isError: status == CommandResponseStatus.error,
      pendingAction: pendingAction,
      pendingTarget: pendingTarget,
      status: status,
      completesFollowUp: completesFollowUp,
    );
  }

  CommandResponseStatus _resolveStatus(AgentCommandPayload payload) {
    final rawStatus = _cleanText(payload.status)?.toLowerCase();

    switch (rawStatus) {
      case 'warning':
        return CommandResponseStatus.warning;
      case 'error':
        return CommandResponseStatus.error;
      case 'success':
        return CommandResponseStatus.success;
    }

    if (payload.isError == true) {
      return CommandResponseStatus.error;
    }

    return CommandResponseStatus.success;
  }

  String? _cleanText(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _extractSummaryFromRaw(String? rawText) {
    final normalized = _cleanText(rawText);
    if (normalized == null) {
      return null;
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return null;
    }

    return lines.first;
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionUiState>((ref) {
  return SessionController();
});
