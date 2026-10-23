import '../../engine/counter_engine.dart';
import '../../engine/engine.dart';
import 'access_remote.dart';
import 'cloud.dart';

/// A scoreboard made with ScoreEase 1.x (`scoreboards/{id}`).
class LegacyBoard {
  final String id;
  final String title;
  final String description;
  final String author;
  final Map<String, int> players;

  /// Team name -> player names. Empty for individual games.
  final Map<String, List<String>> teams;
  final DateTime? lastUpdated;

  const LegacyBoard({
    required this.id,
    required this.title,
    this.description = '',
    this.author = '',
    required this.players,
    this.teams = const {},
    this.lastUpdated,
  });

  factory LegacyBoard.fromMap(String id, Map map) {
    final players = <String, int>{};
    final rawPlayers = map['players'];
    if (rawPlayers is Map) {
      rawPlayers.forEach((k, v) => players[k.toString()] = (v as num?)?.toInt() ?? 0);
    }
    final teams = <String, List<String>>{};
    final rawTeams = map['teams'];
    if (map['isTeamGame'] == true && rawTeams is Map) {
      for (final t in rawTeams.values) {
        if (t is! Map) continue;
        final members = t['players'] is Map ? (t['players'] as Map).keys.map((k) => k.toString()).toList() : <String>[];
        teams[(t['name'] ?? '').toString()] = members;
      }
    }
    final updated = (map['lastUpdated'] as num?)?.toInt();
    return LegacyBoard(
      id: id,
      title: (map['title'] ?? id).toString(),
      description: (map['description'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      players: players,
      teams: teams,
      lastUpdated: updated == null ? null : DateTime.fromMillisecondsSinceEpoch(updated),
    );
  }

  /// Converts to a local counter game with the same scores. Team games become
  /// one participant per team scoring the sum of its players.
  (Game, List<ScoreEvent>) toLocalGame() {
    final now = DateTime.now();
    final participants = <Participant>[];
    final scores = <String, int>{};
    if (teams.isNotEmpty) {
      var i = 0;
      teams.forEach((name, members) {
        final id = 'p$i';
        participants.add(Participant(id: id, name: name, color: i, members: members));
        scores[id] = members.fold(0, (sum, m) => sum + (players[m] ?? 0));
        i++;
      });
    } else {
      var i = 0;
      for (final entry in players.entries) {
        participants.add(Participant(id: 'p$i', name: entry.key, color: i));
        scores['p$i'] = entry.value;
        i++;
      }
    }
    final game = Game(
      id: PushId.next(),
      title: title,
      templateId: 'counter',
      mode: GameMode.counter,
      settings: const {'steps': '1'},
      participants: participants.take(50).toList(),
      createdAt: now,
      updatedAt: now,
    );
    final ts = now.millisecondsSinceEpoch;
    final events = [
      for (final p in game.participants)
        if ((scores[p.id] ?? 0) != 0) ScoreEvent(id: PushId.next(ts), type: CounterEngine.set, data: {'p': p.id, 'v': scores[p.id]}, ts: ts),
    ];
    return (game, events);
  }
}

/// Read-only access to 1.x boards, so old shared links keep working.
class LegacyBoardRemote {
  final AccessRemote access;
  LegacyBoardRemote(this.access);

  Stream<LegacyBoard> watch(String id) async* {
    await Cloud.ensureReady();
    yield* Cloud.db.ref('scoreboards/$id').onValue.handleError((Object e) {
      if (isPermissionDenied(e)) throw CloudException.accessDenied;
      throw e;
    }).map((event) {
      final value = event.snapshot.value;
      if (value is! Map) throw CloudException.notFound;
      return LegacyBoard.fromMap(id, value);
    });
  }
}
