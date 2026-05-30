part of 'landing_bloc.dart';

@immutable
sealed class LandingEvent {}

class LandingGetScoreboardEvent extends LandingEvent {
  final String id;

  LandingGetScoreboardEvent(this.id);
}
