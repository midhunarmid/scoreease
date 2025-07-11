import 'package:scoreease/core/data/models/score_board_model.dart';
import 'package:scoreease/core/domain/repositories/score_board_repository.dart';

class ScoreBoardUseCase {
  final ScoreBoardRepository _scoreBoardRepository;

  ScoreBoardUseCase(this._scoreBoardRepository);

  Future<ScoreBoardModel> getScoreBoard(String id) async {
    return await _scoreBoardRepository.getScoreBoard(id);
  }
}
