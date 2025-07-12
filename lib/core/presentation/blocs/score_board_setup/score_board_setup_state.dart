part of 'score_board_setup_bloc.dart';

@immutable
sealed class ScoreboardSetupState {}

final class ScoreboardSetupInitial extends ScoreboardSetupState {}

class LoadingState extends ScoreboardSetupState {
  final LoadingInfo loadingInfo;

  LoadingState(this.loadingInfo);
}

class ScoreboardSetupSuccessState extends ScoreboardSetupState {
  ScoreboardSetupSuccessState();
}

class ScoreboardSetupErrorState extends ScoreboardSetupState {
  final String title;
  final String message;
  final StatusInfoIconEnum icon;

  ScoreboardSetupErrorState(this.title, this.message, this.icon);
}
