import '../../engine/engine.dart';

/// Wins and streaks for one person, from finished games on this device.
class PlayerStats {
  final String name;
  int played = 0;
  int wins = 0;
  int currentStreak = 0;
  int bestStreak = 0;

  /// Points this person was tagged in while playing for a team.
  int points = 0;
  DateTime? lastPlayed;

  PlayerStats(this.name);

  double get winRate => played == 0 ? 0 : wins / played;
}

/// People are matched by name (case-insensitive). Team members, and anyone
/// swapped in or out of a side, share its result; points come from who was
/// tagged as scoring.
Map<String, PlayerStats> computeStats(List<Game> games) {
  final stats = <String, PlayerStats>{};
  final finished = games.where((g) => g.isFinished).toList()..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  for (final g in finished) {
    for (final p in g.current) {
      final won = g.winners.contains(p.id);
      for (final name in p.everyone) {
        final s = stats.putIfAbsent(name.toLowerCase(), () => PlayerStats(name));
        s.played++;
        s.points += g.memberPoints[name] ?? 0;
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
