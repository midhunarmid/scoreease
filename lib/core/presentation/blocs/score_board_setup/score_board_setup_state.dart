part of 'score_board_setup_bloc.dart';

@immutable
sealed class ScoreBoardSetupState {}

final class ScoreBoardSetupInitial extends ScoreBoardSetupState {}

class LoadingState extends ScoreBoardSetupState {
  final LoadingInfo loadingInfo;

  LoadingState(this.loadingInfo);
}

class ScoreBoardSetupSuccessState extends ScoreBoardSetupState {
  ScoreBoardSetupSuccessState();
}

class ScoreBoardSetupErrorState extends ScoreBoardSetupState {
  final String title;
  final String message;
  final StatusInfoIconEnum icon;

  ScoreBoardSetupErrorState(this.title, this.message, this.icon);
}
