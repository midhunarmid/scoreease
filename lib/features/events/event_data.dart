import '../../data/cloud/cloud.dart';
import '../../data/local/local_store.dart';
import '../../engine/engine.dart';
import '../../engine/event_scoring.dart';
import '../../engine/lineup.dart';
import '../../engine/meet.dart';

/// Scores event [meet] from the games saved on this device.
MeetStandings loadMeetStandings(LocalStore store, Meet meet) =>
    scoreMeet(meet, [for (final g in store.gamesInMeet(meet.id)) GameEngine.compute(g, store.events(g.id))]);

/// Corrects a name in [meet] and in every game played in it. Each game gets a
/// rename event, because a shared game's log is replaced by the cloud copy.
/// Saving doesn't change a game's date, so lists stay in order. [send] pushes
/// the event to games shared from this device; if that fails the game keeps
/// the fix until the cloud copy next replaces it.
Future<void> renameInEvent(
  LocalStore store,
  Meet meet,
  String from,
  String to, {
  required Future<void> Function(String code, ScoreEvent event) send,
}) async {
  await store.saveMeet(meet.renamed(from, to).copyWith(updatedAt: DateTime.now()));
  for (final g in store.gamesInMeet(meet.id)) {
    if (!g.current.any((p) => sameName(p.name, from) || p.everyone.any((n) => sameName(n, from)))) continue;
    final now = DateTime.now().millisecondsSinceEpoch;
    final event = ScoreEvent(id: PushId.next(now), type: EventTypes.rename, data: {'f': from, 'n': to}, ts: now, by: Cloud.uid ?? 'local');
    final events = [...store.events(g.id), event];
    await store.saveEvents(g.id, events);
    await store.saveGame(GameEngine.compute(g, events).toSaved(g.updatedAt));
    if (g.shareCode != null && g.isOwner) {
      try {
        await send(g.shareCode!, event);
      } catch (_) {
        // Offline: the device copy is still right.
      }
    }
  }
  final players = store.players();
  if (players.any((p) => sameName(p.name, to))) return;
  for (final p in players) {
    if (sameName(p.name, from)) await store.savePlayer(p.copyWith(name: to));
  }
}

/// "Reds +5 · Blues +1", best first.
String awardLine(Meet meet, Map<String, int> teamPoints) {
  final entries = teamPoints.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => '${meet.team(e.key)?.name ?? '?'} +${e.value}').join(' · ');
}
