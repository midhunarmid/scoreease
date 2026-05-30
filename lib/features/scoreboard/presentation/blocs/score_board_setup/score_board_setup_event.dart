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

class ScoreboardUpdatePlayerScoreEvent extends ScoreboardSetupEvent {
  final String playerName;
  final ScoreboardEntity scoreboardEntity;
  final int delta;

  ScoreboardUpdatePlayerScoreEvent(this.playerName, this.scoreboardEntity, {this.delta = 1});
}

class ScoreboardResetScoresEvent extends ScoreboardSetupEvent {
  final ScoreboardEntity scoreboardEntity;

  ScoreboardResetScoresEvent(this.scoreboardEntity);
}

class ScoreboardListenPlayerScoreEvent extends ScoreboardSetupEvent {
  final String id;

  ScoreboardListenPlayerScoreEvent(this.id);
}

class ScoreboardGetEvent extends ScoreboardSetupEvent {
  final String id;

  ScoreboardGetEvent(this.id);
}

class ScoreboardStopListenPlayerScoreEvent extends ScoreboardSetupEvent {}
