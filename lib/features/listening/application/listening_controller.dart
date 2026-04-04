import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ListeningStatus { idle, listening, processing }

class ListeningState {
  const ListeningState(this.status);

  final ListeningStatus status;
}

class ListeningController extends StateNotifier<ListeningState> {
  ListeningController() : super(const ListeningState(ListeningStatus.idle));

  void startListening() {
    state = const ListeningState(ListeningStatus.listening);
  }

  void setProcessing() {
    state = const ListeningState(ListeningStatus.processing);
  }

  void reset() {
    state = const ListeningState(ListeningStatus.idle);
  }
}

final listeningControllerProvider =
    StateNotifierProvider<ListeningController, ListeningState>((ref) {
  return ListeningController();
});
