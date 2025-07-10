import 'package:scoreease/core/data/datasources/remote_data_source.dart';
import 'package:scoreease/core/data/models/score_board_model.dart';
import 'package:scoreease/core/domain/repositories/user_repository.dart';

class ScoreBoardRepositoryImpl implements ScoreBoardRepository {
  final RemoteDataSource _remoteDataSource;

  ScoreBoardRepositoryImpl(this._remoteDataSource);

  @override
  Future<ScoreBoardModel> getScoreBoard(String id) {
    return _remoteDataSource.getScoreBoard(id);
  }
}
