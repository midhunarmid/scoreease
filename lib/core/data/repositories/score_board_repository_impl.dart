import 'package:scoreease/core/data/datasources/local_data_source.dart';
import 'package:scoreease/core/data/datasources/remote_data_source.dart';
import 'package:scoreease/core/data/models/score_board_model.dart';
import 'package:scoreease/core/domain/repositories/score_board_repository.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';

class ScoreBoardRepositoryImpl implements ScoreBoardRepository {
  final RemoteDataSource _remoteDataSource;
  final LocalDataSource _localDataSource;

  ScoreBoardRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<ScoreBoardModel> getScoreBoard(String id) async {
    ScoreBoardModel? cachedItems = await _localDataSource.getScoreBoard(id: id);
    ScoreBoardModel? serverItems =
        await _remoteDataSource.getScoreBoard(id: id);
    if (serverItems == null && cachedItems == null) {
      throw const MyAppException(
        title: "Score Board Not Found",
        message: "No score board found with that ID",
      );
    } else {
      // The null assertion below is safe because the previous check ensures that at least one of serverItems or cachedItems is non-null.
      return (serverItems ?? cachedItems)!;
    }
  }
}
