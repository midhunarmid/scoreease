import '../../engine/engine.dart';

/// Wins and streaks for one person, from finished games on this device.
class PlayerStats {
  final String name;
  int played = 0;
  int wins = 0;
  int currentStreak = 0;
  int bestStreak = 0;
  DateTime? lastPlayed;

  PlayerStats(this.name);

  double get winRate => played == 0 ? 0 : wins / played;
}

/// People are matched by name (case-insensitive). Team members share their
/// team's result.
Map<String, PlayerStats> computeStats(List<Game> games) {
  final stats = <String, PlayerStats>{};
  final finished = games.where((g) => g.isFinished).toList()..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  for (final g in finished) {
    for (final p in g.participants) {
      final won = g.winners.contains(p.id);
      for (final name in p.isTeam ? p.members : [p.name]) {
        final s = stats.putIfAbsent(name.toLowerCase(), () => PlayerStats(name));
        s.played++;
        s.lastPlayed = g.updatedAt;
        if (won) {
          s.wins++;
          s.currentStreak++;
          if (s.currentStreak > s.bestStreak) s.bestStreak = s.currentStreak;
        } else {
          s.currentStreak = 0;
        }
      }
    }
  }
  return stats;
}
