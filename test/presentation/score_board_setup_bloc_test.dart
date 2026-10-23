import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/team_entity.dart';
import 'package:scoreease/features/scoreboard/domain/usecases/score_board_usecase.dart';
import 'package:scoreease/features/scoreboard/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';

import '../helpers/fake_scoreboard_repository.dart';

void main() {
  late FakeScoreboardRepository repository;
  late ScoreboardSetupBloc bloc;

  setUp(() {
    repository = FakeScoreboardRepository()
      ..addBoard(const ScoreboardEntity(id: 'taken', title: 'Taken', players: {'ann': 4}));
    GetIt.instance.registerSingleton<ScoreboardUseCase>(ScoreboardUseCase(repository));
    bloc = ScoreboardSetupBloc();
  });

  tearDown(() async {
    await bloc.close();
    await GetIt.instance.reset();
  });

  Future<ScoreboardSetupState> lastStateAfter(ScoreboardSetupEvent event) async {
    final states = <ScoreboardSetupState>[];
    final subscription = bloc.stream.listen(states.add);
    bloc.add(event);
    await Future.delayed(const Duration(milliseconds: 700));
    await subscription.cancel();
    return states.last;
  }

  group('basic details', () {
    test('rejects an empty ID', () async {
      final state = await lastStateAfter(ScoreboardSetupBasicSubmitEvent(const ScoreboardEntity(id: '', author: 'Midhun')));
      expect(state, isA<ScoreboardSetupErrorState>());
    });

    test('rejects a short author name', () async {
      final state = await lastStateAfter(ScoreboardSetupBasicSubmitEvent(const ScoreboardEntity(id: 'friday', author: 'Mi')));
      expect(state, isA<ScoreboardSetupErrorState>());
    });

    test('rejects an ID that is already taken', () async {
      final state = await lastStateAfter(ScoreboardSetupBasicSubmitEvent(const ScoreboardEntity(id: 'taken', author: 'Midhun')));
      expect(state, isA<ScoreboardSetupErrorState>());
      expect((state as ScoreboardSetupErrorState).title, contains('Unavailable'));
    });

    test('accepts a free ID', () async {
      final state = await lastStateAfter(ScoreboardSetupBasicSubmitEvent(const ScoreboardEntity(id: 'friday', author: 'Midhun')));
      expect(state, isA<ScoreboardSetupBasicSuccessState>());
    });
  });

  group('players', () {
    test('a team game needs two teams', () async {
      final state = await lastStateAfter(ScoreboardSetupPlayerNamesSubmitEvent(const ScoreboardEntity(
        id: 'friday',
        isTeamGame: true,
        teams: {'Reds': TeamEntity(name: 'Reds', players: {'ann': true})},
      )));
      expect(state, isA<ScoreboardSetupErrorState>());
    });

    test('a solo game needs players', () async {
      final state = await lastStateAfter(
          ScoreboardSetupPlayerNamesSubmitEvent(const ScoreboardEntity(id: 'friday', players: {})));
      expect(state, isA<ScoreboardSetupErrorState>());
    });
  });

  group('scoring', () {
    test('a tap increments only that player', () async {
      final board = repository.boards['taken']!;
      final state = await lastStateAfter(ScoreboardUpdatePlayerScoreEvent('ann', board, delta: 2));
      expect(state, isA<ScoreboardScoreUpdateSuccessState>());
      expect(repository.boards['taken']!.players, {'ann': 6});
    });

    test('reset sets every score to zero', () async {
      final board = repository.boards['taken']!;
      await lastStateAfter(ScoreboardResetScoresEvent(board));
      expect(repository.boards['taken']!.players, {'ann': 0});
    });
  });
}
