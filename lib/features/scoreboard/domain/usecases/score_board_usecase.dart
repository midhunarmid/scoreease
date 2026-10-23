import 'package:scoreease/core/utils/global.dart';
import 'package:scoreease/core/utils/security_helper.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/domain/repositories/score_board_repository.dart';

class ScoreboardUseCase {
  final ScoreboardRepository _scoreboardRepository;

  ScoreboardUseCase(this._scoreboardRepository);

  Future<bool> exists(String id) async {
    return await _scoreboardRepository.exists(id);
  }

  Future<ScoreboardEntity> getScoreboard(String id) async {
    return await _scoreboardRepository.getScoreboard(id);
  }

  Future<String> createScoreboard(ScoreboardEntity scoreboardEntity) async {
    return await _scoreboardRepository.createScoreboard(scoreboardEntity);
  }

  Future<String> updateScoreboard(ScoreboardEntity scoreboardEntity) async {
    return await _scoreboardRepository.updateScoreboard(scoreboardEntity);
  }

  Future<void> setPlayerScores(String id, Map<String, int> scores) async {
    return await _scoreboardRepository.setPlayerScores(id, scores);
  }

  Future<void> incrementPlayerScore(String id, String player, int delta) async {
    return await _scoreboardRepository.incrementPlayerScore(id, player, delta);
  }

  Stream<ScoreboardEntity> getScoreboardStream(String id) {
    return _scoreboardRepository.getScoreboardStream(id);
  }

  Future<bool> hasAccess(String id, AccessLevel level) async {
    return await _scoreboardRepository.hasAccess(id, level);
  }

  /// Checks [password] against the board's [level] password on the server.
  /// On success the user keeps that access until the password changes or they
  /// clear saved access in settings.
  Future<bool> unlock(String id, AccessLevel level, String password) async {
    final unlocked = await _scoreboardRepository.unlock(id, level, SecurityHelper.hashPassword(password));
    if (unlocked) {
      await GlobalValues.rememberUnlockedScoreboard(id);
    }
    return unlocked;
  }

  /// Removes every saved password grant this browser has made.
  Future<void> revokeAllAccess() async {
    final ids = await GlobalValues.getUnlockedScoreboards();
    await _scoreboardRepository.revokeAccess(ids);
    await GlobalValues.clearUnlockedScoreboards();
  }
}
