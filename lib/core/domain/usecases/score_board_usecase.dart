import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/domain/repositories/score_board_repository.dart';

class ScoreboardUseCase {
  final ScoreboardRepository _scoreboardRepository;

  ScoreboardUseCase(this._scoreboardRepository);

  Future<ScoreboardEntity> getScoreboard(String id) async {
    return await _scoreboardRepository.getScoreboard(id);
  }
}
