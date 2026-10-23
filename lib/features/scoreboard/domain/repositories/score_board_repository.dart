import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';

abstract class ScoreboardRepository {
  Future<bool> exists(String id);
  Future<ScoreboardEntity> getScoreboard(String id);
  Future<String> createScoreboard(ScoreboardEntity scoreboardEntity);
  Future<String> updateScoreboard(ScoreboardEntity scoreboardEntity);
  Future<void> setPlayerScores(String id, Map<String, int> scores);
  Future<void> incrementPlayerScore(String id, String player, int delta);
  Stream<ScoreboardEntity> getScoreboardStream(String id);
  Future<bool> hasAccess(String id, AccessLevel level);
  Future<bool> unlock(String id, AccessLevel level, String passwordHash);
  Future<void> revokeAccess(Iterable<String> ids);
}
