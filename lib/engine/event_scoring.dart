import 'engine.dart';
import 'meet.dart';
import 'placements_engine.dart';

/// What one game of an event gave each team. Empty until the game ends.
class GameAward {
  final GameSnapshot snapshot;
  final Map<String, int> teamPoints;

  const GameAward(this.snapshot, this.teamPoints);

  Game get game => snapshot.game;
  bool get counted => snapshot.finished;
}

/// One person's event record.
class PersonLine {
  final String name;
  final String? teamId;

  /// Points from their own places in individual games.
  int points = 0;
  int played = 0;

  /// 1st places in individual games.
  int wins = 0;

  /// Points they were tagged as scoring in team games ("who scored").
  int scored = 0;

  PersonLine(this.name, this.teamId);

  double get perGame => played == 0 ? 0 : points / played;
}

/// The event leaderboard: team totals, what each game gave, and people.
class MeetStandings {
  final Meet meet;
  final Map<String, int> teamTotals;

  /// Games oldest first, finished or not.
  final List<GameAward> games;

  /// Best first: points, then fewer games played, then wins.
  final List<PersonLine> people;

  const MeetStandings(this.meet, this.teamTotals, this.games, this.people);

  /// Teams on top. More than one is a draw; none before anything counts.
  List<String> get leaders {
    if (teamTotals.values.every((v) => v == 0)) return const [];
    final best = teamTotals.values.reduce((a, b) => a > b ? a : b);
    return [for (final MapEntry(:key, :value) in teamTotals.entries) if (value == best) key];
  }

  /// "Reds won!", "It's a draw!" or null before any points.
  String? get resultText => switch (leaders) {
        [] => null,
        [final id] => '${meet.team(id)?.name ?? '?'} won!',
        _ => 'It\'s a draw!',
      };

  /// Teams ordered by total, best first.
  List<MeetTeam> get rankedTeams => [...meet.teams]..sort((a, b) => (teamTotals[b.id] ?? 0).compareTo(teamTotals[a.id] ?? 0));
}

/// Works out an event's scores from its games. Each finished game awards
/// points by place, using the game's own points table or the event's:
/// - a player's points go to them and to their team;
/// - a team's points go to the team, and its roster counts as having played.
/// Players who share a place get the same points.
MeetStandings scoreMeet(Meet meet, List<GameSnapshot> snapshots) {
  final totals = {for (final t in meet.teams) t.id: 0};
  final people = <String, PersonLine>{};
  for (final t in meet.teams) {
    for (final m in t.members) {
      people.putIfAbsent(m.toLowerCase(), () => PersonLine(m, t.id));
    }
  }
  PersonLine person(String name) => people.putIfAbsent(name.toLowerCase(), () => PersonLine(name, meet.teamOf(name)?.id));

  final sorted = [...snapshots]..sort((a, b) => a.game.createdAt.compareTo(b.game.createdAt));
  final awards = <GameAward>[];
  for (final snap in sorted) {
    final teamPoints = <String, int>{};
    if (snap.finished) {
      final table = parsePlacePoints(snap.game.stringSetting('placePoints') ?? meet.placePoints);
      for (final s in snap.standings) {
        final p = snap.game.participant(s.participantId);
        if (p == null) continue;
        // Ended by hand mid-way: those still in share the win.
        final place = s.rank > 0 ? s.rank : (snap.winners.contains(p.id) ? 1 : 0);
        final points = pointsForPlace(table, place);
        final teamId = p.teamId;
        if (teamId != null && totals.containsKey(teamId)) {
          teamPoints[teamId] = (teamPoints[teamId] ?? 0) + points;
        }
        if (p.isTeam) {
          for (final m in p.members) {
            person(m).played++;
          }
        } else {
          final line = person(p.name);
          line.played++;
          line.points += points;
          if (place == 1) line.wins++;
        }
      }
      for (final MapEntry(:key, :value) in snap.memberPointsByName.entries) {
        person(key).scored += value;
      }
      teamPoints.forEach((id, v) => totals[id] = totals[id]! + v);
    }
    awards.add(GameAward(snap, teamPoints));
  }

  final ranked = people.values.toList()
    ..sort((a, b) {
      var c = b.points.compareTo(a.points);
      if (c == 0) c = a.played.compareTo(b.played);
      if (c == 0) c = b.wins.compareTo(a.wins);
      if (c == 0) c = b.scored.compareTo(a.scored);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return MeetStandings(meet, totals, awards, ranked);
}
