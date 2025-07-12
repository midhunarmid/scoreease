import 'package:scoreease/core/data/datasources/local_data_source.dart';
import 'package:scoreease/core/data/datasources/remote_data_source.dart';
import 'package:scoreease/core/data/repositories/score_board_repository_impl.dart';
import 'package:scoreease/core/domain/repositories/score_board_repository.dart';
import 'package:scoreease/core/domain/usecases/score_board_usecase.dart';
import 'package:get_it/get_it.dart';

void setupDependencies() {
  // Register the ScoreboardRepository and RemoteDataSource with GetIt
  GetIt.instance.registerLazySingleton<ScoreboardRepository>(
      () => ScoreboardRepositoryImpl(RemoteDataSource(), LocalDataSource()));

  // Register the ScoreboardUseCase with GetIt, initializing it with ScoreboardRepository
  GetIt.instance.registerLazySingleton<ScoreboardUseCase>(
      () => ScoreboardUseCase(GetIt.instance<ScoreboardRepository>()));
}
