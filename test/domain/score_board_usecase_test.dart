import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/core/utils/global.dart';
import 'package:scoreease/core/utils/security_helper.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/domain/usecases/score_board_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_scoreboard_repository.dart';

void main() {
  late FakeScoreboardRepository repository;
  late ScoreboardUseCase useCase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeScoreboardRepository()
      ..addBoard(
        const ScoreboardEntity(id: 'b1', title: 'Game', players: {'ann': 0}),
        passwords: {AccessLevel.read: 'letmein'},
      );
    useCase = ScoreboardUseCase(repository);
  });

  test('SecurityHelper hashes to lowercase SHA-256 hex', () {
    expect(
      SecurityHelper.hashPassword('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(SecurityHelper.hashPassword(''), '');
  });

  test('unlock sends the hash, not the password', () async {
    expect(await useCase.unlock('b1', AccessLevel.read, 'wrong'), isFalse);
    expect(await useCase.hasAccess('b1', AccessLevel.read), isFalse);

    expect(await useCase.unlock('b1', AccessLevel.read, 'letmein'), isTrue);
    expect(await useCase.hasAccess('b1', AccessLevel.read), isTrue);
  });

  test('only successful unlocks are remembered', () async {
    await useCase.unlock('b1', AccessLevel.read, 'wrong');
    expect(await GlobalValues.getUnlockedScoreboards(), isEmpty);

    await useCase.unlock('b1', AccessLevel.read, 'letmein');
    await useCase.unlock('b1', AccessLevel.read, 'letmein');
    expect(await GlobalValues.getUnlockedScoreboards(), ['b1']);
  });

  test('revokeAllAccess removes server grants and local records', () async {
    SharedPreferences.setMockInitialValues({'access_read_old': true});
    await useCase.unlock('b1', AccessLevel.read, 'letmein');

    await useCase.revokeAllAccess();

    expect(repository.revoked, ['b1']);
    expect(await useCase.hasAccess('b1', AccessLevel.read), isFalse);
    expect(await GlobalValues.getUnlockedScoreboards(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('access_read_old'), isFalse);
  });

  test('incrementPlayerScore adds to the stored score', () async {
    await useCase.incrementPlayerScore('b1', 'ann', 2);
    await useCase.incrementPlayerScore('b1', 'ann', -1);
    expect(repository.boards['b1']!.players, {'ann': 1});
  });
}
