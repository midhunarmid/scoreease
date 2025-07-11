part of 'landing_bloc.dart';

@immutable
sealed class LandingEvent {}

class LandingGetScoreBoardEvent extends LandingEvent {
  final String id;

  LandingGetScoreBoardEvent(this.id);
}
