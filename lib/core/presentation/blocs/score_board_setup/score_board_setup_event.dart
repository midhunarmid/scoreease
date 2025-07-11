part of 'score_board_setup_bloc.dart';

@immutable
sealed class ScoreBoardSetupEvent {}

class ScoreBoardSetupSubmitEvent extends ScoreBoardSetupEvent {
  final String id;

  ScoreBoardSetupSubmitEvent(this.id);
}
