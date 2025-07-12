part of 'score_board_setup_bloc.dart';

@immutable
sealed class ScoreboardSetupEvent {}

class ScoreboardSetupBasicSubmitEvent extends ScoreboardSetupEvent {
  final ScoreboardEntity scoreboardEntity;

  ScoreboardSetupBasicSubmitEvent(this.scoreboardEntity);
}

class ScoreboardSetupPlayerNamesSubmitEvent extends ScoreboardSetupEvent {
  final ScoreboardEntity scoreboardEntity;

  ScoreboardSetupPlayerNamesSubmitEvent(this.scoreboardEntity);
}

class ScoreboardSetupFinalSubmitEvent extends ScoreboardSetupEvent {
  final ScoreboardEntity scoreboardEntity;

  ScoreboardSetupFinalSubmitEvent(this.scoreboardEntity);
}