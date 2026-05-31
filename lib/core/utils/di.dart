
import 'package:scoreease/features/scoreboard/data/datasources/scoreboard_remote_data_source.dart';
import 'package:scoreease/features/scoreboard/data/repositories/score_board_repository_impl.dart';
import 'package:scoreease/features/scoreboard/domain/repositories/score_board_repository.dart';
import 'package:scoreease/features/scoreboard/domain/usecases/score_board_usecase.dart';
import 'package:get_it/get_it.dart';

void setupDependencies() {
  // Register the ScoreboardRepository and ScoreboardRemoteDataSource with GetIt
  GetIt.instance.registerLazySingleton<ScoreboardRepository>(
      () => ScoreboardRepositoryImpl(ScoreboardRemoteDataSource()));

  // Register the ScoreboardUseCase with GetIt, initializing it with ScoreboardRepository
  GetIt.instance.registerLazySingleton<ScoreboardUseCase>(
      () => ScoreboardUseCase(GetIt.instance<ScoreboardRepository>()));
}
