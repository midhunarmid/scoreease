import 'package:scoreease/core/data/models/score_board_model.dart';

abstract class ScoreBoardRepository {
  Future<ScoreBoardModel> getScoreBoard(String id);
}
