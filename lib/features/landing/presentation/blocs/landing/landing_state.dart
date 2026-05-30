part of 'landing_bloc.dart';

@immutable
sealed class LandingState {}

final class LandingInitial extends LandingState {}

class LoadingState extends LandingState {
  final LoadingInfo loadingInfo;

  LoadingState(this.loadingInfo);
}

class LandingScoreCardReceivedState extends LandingState {
  final ScoreboardEntity scoreboard;

  LandingScoreCardReceivedState(this.scoreboard);
}

class LandingErrorState extends LandingState {
  final String title;
  final String message;
  final StatusInfoIconEnum icon;

  LandingErrorState(this.title, this.message, this.icon);
}
