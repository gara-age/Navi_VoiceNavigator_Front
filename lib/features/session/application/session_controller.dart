import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/response_models.dart';

class SessionUiState {
  const SessionUiState({
    this.lastSummary,
    this.lastFollowUp,
    this.isBusy = false,
    this.isRecording = false,
  });

  final String? lastSummary;
  final String? lastFollowUp;
  final bool isBusy;
  final bool isRecording;

  SessionUiState copyWith({
    String? lastSummary,
    String? lastFollowUp,
    bool? isBusy,
    bool? isRecording,
  }) {
    return SessionUiState(
      lastSummary: lastSummary ?? this.lastSummary,
      lastFollowUp: lastFollowUp ?? this.lastFollowUp,
      isBusy: isBusy ?? this.isBusy,
      isRecording: isRecording ?? this.isRecording,
    );
  }
}

class SessionController extends StateNotifier<SessionUiState> {
  SessionController() : super(const SessionUiState());

  Future<CommandResponseModel> submitTextCommand(String text) async {
    state = state.copyWith(isBusy: true);

    await Future<void>.delayed(const Duration(milliseconds: 1000));

    final response = CommandResponseModel(
      transcript: text,
      summary: '텍스트 명령 "$text" 처리 결과입니다.',
      followUp: '다음 작업도 진행할까요?',
    );

    state = state.copyWith(
      isBusy: false,
      lastSummary: response.summary,
      lastFollowUp: response.followUp,
    );

    return response;
  }

  Future<void> startListening() async {
    state = state.copyWith(isRecording: true);
  }

  Future<CommandResponseModel> stopListeningAndProcess() async {
    state = state.copyWith(isRecording: false, isBusy: true);

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    const response = CommandResponseModel(
      transcript: '유튜브에서 고양이 영상 찾아줘',
      summary: '유튜브 검색 결과를 준비했습니다.',
      followUp: '첫 번째 결과를 재생할까요?',
    );

    state = state.copyWith(
      isBusy: false,
      lastSummary: response.summary,
      lastFollowUp: response.followUp,
    );

    return response;
  }

  Future<CommandResponseModel> triggerScreenRead() async {
    state = state.copyWith(isBusy: true);

    await Future<void>.delayed(const Duration(milliseconds: 900));

    const response = CommandResponseModel(
      transcript: 'screen_read',
      summary: '현재 화면에는 왼쪽 기능 패널과 중앙 결과 영역이 있습니다.',
      followUp: '더 자세히 읽어드릴까요?',
    );

    state = state.copyWith(
      isBusy: false,
      lastSummary: response.summary,
      lastFollowUp: response.followUp,
    );

    return response;
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionUiState>((ref) {
  return SessionController();
});
