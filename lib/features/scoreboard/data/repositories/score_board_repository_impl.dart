import 'package:scoreease/features/scoreboard/data/datasources/scoreboard_remote_data_source.dart';
import 'package:scoreease/features/scoreboard/data/mappers/access_mapper.dart';
import 'package:scoreease/features/scoreboard/data/mappers/scoreboard_mapper.dart';
import 'package:scoreease/features/scoreboard/data/models/access_model.dart';
import 'package:scoreease/features/scoreboard/data/models/scoreboard_model.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/domain/repositories/score_board_repository.dart';
import 'package:scoreease/core/utils/my_app_exception.dart';

class ScoreboardRepositoryImpl implements ScoreboardRepository {
  final ScoreboardRemoteDataSource _remoteDataSource;

  ScoreboardRepositoryImpl(this._remoteDataSource);

  static const MyAppException _saveError = MyAppException(
    title: "Scoreboard Save Error",
    message: "Failed to save the scoreboard",
  );

  @override
  Future<bool> exists(String id) async {
    return await _remoteDataSource.getAccessMeta(id) != null;
  }

  @override
  Future<ScoreboardEntity> getScoreboard(String id) async {
    ScoreboardModel? serverItems = await _remoteDataSource.getScoreboard(id: id);
    if (serverItems == null) {
      throw const MyAppException(
        title: "Scoreboard Not Found",
        message: "No score board found with that ID",
      );
    } else {
      return ScoreboardMapper.toEntity(serverItems);
    }
  }

  @override
  Future<String> createScoreboard(ScoreboardEntity scoreboardEntity) async {
    String? savedDocId = await _remoteDataSource.createScoreboard(
      scoreboardModel: ScoreboardMapper.fromEntity(scoreboardEntity),
      secrets: AccessMapper.secretsFromEntity(scoreboardEntity.access ?? const AccessEntity()),
    );
    if (savedDocId == null) throw _saveError;
    return savedDocId;
  }

  @override
  Future<String> updateScoreboard(ScoreboardEntity scoreboardEntity) async {
    AccessModel? secrets =
        scoreboardEntity.access == null ? null : AccessMapper.secretsFromEntity(scoreboardEntity.access!);
    String? savedDocId = await _remoteDataSource.updateScoreboard(
      scoreboardModel: ScoreboardMapper.fromEntity(scoreboardEntity),
      secrets: secrets,
    );
    if (savedDocId == null) throw _saveError;
    return savedDocId;
  }

  @override
  Future<void> setPlayerScores(String id, Map<String, int> scores) {
    return _remoteDataSource.setPlayerScores(id: id, scores: scores);
  }

  @override
  Stream<ScoreboardEntity> getScoreboardStream(String id) {
    return _remoteDataSource.listenToScoreboard(id).map((scoreboardModel) {
      return ScoreboardMapper.toEntity(scoreboardModel);
    });
  }

  @override
  Future<bool> hasAccess(String id, AccessLevel level) => _remoteDataSource.hasAccess(id, level);

  @override
  Future<bool> unlock(String id, AccessLevel level, String passwordHash) =>
      _remoteDataSource.unlock(id, level, passwordHash);

  @override
  Future<void> revokeAccess(Iterable<String> ids) => _remoteDataSource.revokeGrants(ids);
}
