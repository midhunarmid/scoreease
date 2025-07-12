part of 'score_board_setup_bloc.dart';

@immutable
sealed class ScoreboardSetupState {}

final class ScoreboardSetupInitial extends ScoreboardSetupState {}

class LoadingState extends ScoreboardSetupState {
  final LoadingInfo loadingInfo;

  LoadingState(this.loadingInfo);
}

class ScoreboardSetupBasicSuccessState extends ScoreboardSetupState {
  final ScoreboardEntity scoreboardEntity;
  ScoreboardSetupBasicSuccessState(this.scoreboardEntity);
}

class ScoreboardSetupPlayerNamesSuccessState extends ScoreboardSetupState {
  final ScoreboardEntity scoreboardEntity;
  ScoreboardSetupPlayerNamesSuccessState(this.scoreboardEntity);
}

class ScoreboardSetupSuccessState extends ScoreboardSetupState {
  final String id;
  ScoreboardSetupSuccessState(this.id);
}

class ScoreboardSetupErrorState extends ScoreboardSetupState {
  final String title;
  final String message;
  final StatusInfoIconEnum icon;

  ScoreboardSetupErrorState(this.title, this.message, this.icon);
}
