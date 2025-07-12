import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';

abstract class ScoreboardRepository {
  Future<ScoreboardEntity> getScoreboard(String id);
  Future<String> saveScoreboard(ScoreboardEntity scoreboardEntity);
}
