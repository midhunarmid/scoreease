import 'package:scoreease/features/scoreboard/data/datasources/scoreboard_local_data_source.dart';
import 'package:scoreease/features/scoreboard/data/datasources/scoreboard_remote_data_source.dart';
import 'package:scoreease/features/scoreboard/data/mappers/scoreboard_mapper.dart';
import 'package:scoreease/features/scoreboard/data/models/scoreboard_model.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/domain/repositories/score_board_repository.dart';
import 'package:scoreease/core/utils/constants.dart';
import 'package:scoreease/core/utils/my_app_exception.dart';

class ScoreboardRepositoryImpl implements ScoreboardRepository {
  final ScoreboardRemoteDataSource _remoteDataSource;
  final ScoreboardLocalDataSource _localDataSource;

  ScoreboardRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<ScoreboardEntity> getScoreboard(String id) async {
    ScoreboardModel? cachedItems;
    try {
      cachedItems = await _localDataSource.getScoreboard(id: id);
    } catch (e) {
      // If there's an error fetching from local, we can log it but continue to fetch from remote.
      appLogger.e("Error fetching cached scoreboard: $e");
    }
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

  @override
  Stream<ScoreboardEntity> getScoreboardStream(String id) {
    return _remoteDataSource.listenToScoreboard(id).map((scoreboardModel) {
      return ScoreboardMapper.toEntity(scoreboardModel);
    });
  }
}
