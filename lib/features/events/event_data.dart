import '../../data/local/local_store.dart';
import '../../engine/engine.dart';
import '../../engine/event_scoring.dart';
import '../../engine/meet.dart';

/// Scores event [meet] from the games saved on this device.
MeetStandings loadMeetStandings(LocalStore store, Meet meet) =>
    scoreMeet(meet, [for (final g in store.gamesInMeet(meet.id)) GameEngine.compute(g, store.events(g.id))]);

/// "Reds +5 · Blues +1", best first.
String awardLine(Meet meet, Map<String, int> teamPoints) {
  final entries = teamPoints.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => '${meet.team(e.key)?.name ?? '?'} +${e.value}').join(' · ');
}
