import 'package:scoreease/core/data/datasources/remote_data_source.dart';
import 'package:scoreease/core/data/repositories/user_repository_impl.dart';
import 'package:scoreease/core/domain/repositories/user_repository.dart';
import 'package:scoreease/core/domain/usecases/score_board_usecase.dart';
import 'package:get_it/get_it.dart';

void setupDependencies() {
  // Register the ScoreBoardRepository and RemoteDataSource with GetIt
  GetIt.instance.registerLazySingleton<ScoreBoardRepository>(
      () => ScoreBoardRepositoryImpl(RemoteDataSource()));

  // Register the ScoreBoardUseCase with GetIt, initializing it with ScoreBoardRepository
  GetIt.instance.registerLazySingleton<ScoreBoardUseCase>(
      () => ScoreBoardUseCase(GetIt.instance<ScoreBoardRepository>()));
}
