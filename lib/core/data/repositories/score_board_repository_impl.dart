import 'package:scoreease/core/data/datasources/local_data_source.dart';
import 'package:scoreease/core/data/datasources/remote_data_source.dart';
import 'package:scoreease/core/data/mappers/scoreboard_mapper.dart';
import 'package:scoreease/core/data/models/scoreboard_model.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/domain/repositories/score_board_repository.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';

class ScoreboardRepositoryImpl implements ScoreboardRepository {
  final RemoteDataSource _remoteDataSource;
  final LocalDataSource _localDataSource;

  ScoreboardRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<ScoreboardEntity> getScoreboard(String id) async {
    ScoreboardModel? cachedItems = await _localDataSource.getScoreboard(id: id);
    ScoreboardModel? serverItems = await _remoteDataSource.getScoreboard(id: id);
    if (serverItems == null && cachedItems == null) {
      throw const MyAppException(
        title: "Scoreboard Not Found",
        message: "No score board found with that ID",
      );
    } else {
      // The null assertion below is safe because the previous check ensures that at least one of serverItems or cachedItems is non-null.
      return ScoreboardMapper.toEntity((serverItems ?? cachedItems)!);
    }
  }

  @override
  Future<String> saveScoreboard(ScoreboardEntity scoreboardEntity) async {
    ScoreboardModel scoreboardModel = ScoreboardMapper.fromEntity(scoreboardEntity);
    String? savedDocId = await _remoteDataSource.saveScoreboard(scoreboardModel: scoreboardModel);

    if (savedDocId == null) {
      throw const MyAppException(
        title: "Scoreboard Save Error",
        message: "Failed to save the scoreboard",
      );
    } else {
      return savedDocId;
    }
  }
}
