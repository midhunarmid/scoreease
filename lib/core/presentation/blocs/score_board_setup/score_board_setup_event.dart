part of 'score_board_setup_bloc.dart';

@immutable
sealed class ScoreboardSetupEvent {}

class ScoreboardSetupSubmitEvent extends ScoreboardSetupEvent {
  final String id;

  ScoreboardSetupSubmitEvent(this.id);
}
