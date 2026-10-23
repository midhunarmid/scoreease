import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/features/scoreboard/data/mappers/access_mapper.dart';
import 'package:scoreease/features/scoreboard/data/mappers/scoreboard_mapper.dart';
import 'package:scoreease/features/scoreboard/data/models/access_model.dart';
import 'package:scoreease/features/scoreboard/data/models/scoreboard_model.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';

void main() {
  final serverBoard = <String, dynamic>{
    'id': 'friday',
    'title': 'Friday Quiz',
    'author': 'Midhun',
    'ownerId': 'uid-1',
    'createdAt': 1700000000000,
    'lastUpdated': 1700000500000,
    'players': {'ann': 3, 'bob': 5},
    'isTeamGame': true,
    'teams': {
      'Reds': {
        'name': 'Reds',
        'players': {'ann': true},
      },
    },
    // Boards saved before 1.5.0 carry their hashes here.
    'access': {'read': 'abc'},
  };

  group('ScoreboardModel', () {
    test('reads a board from the database', () {
      final model = ScoreboardModel.fromMap(serverBoard);
      expect(model.id, 'friday');
      expect(model.players, {'ann': 3, 'bob': 5});
      expect(model.teams?['Reds']?.players, {'ann': true});
      expect(model.isTeamGame, isTrue);
    });

    test('never reads or writes password data on the board', () {
      final model = ScoreboardModel.fromMap(serverBoard);
      expect(model.access, isNull);
      expect(model.toMap().containsKey('access'), isFalse);
    });

    test('stamps lastUpdated with the server time', () {
      final map = ScoreboardModel.fromMap(serverBoard).toMap();
      expect(map['lastUpdated'], isA<Object>());
      expect(map['lastUpdated'], ServerValue.timestamp);
    });
  });

  group('ScoreboardMapper', () {
    test('maps timestamps and access flags to the entity', () {
      final model = ScoreboardModel.fromMap(serverBoard)
          .copyWith(access: const AccessMetaModel(ownerId: 'uid-1', readProtected: true));
      final entity = ScoreboardMapper.toEntity(model);
      expect(entity.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(entity.access?.readProtected, isTrue);
      expect(entity.access?.writeProtected, isFalse);
      expect(entity.access?.read, isNull);
    });

    test('round-trips players and teams', () {
      final entity = ScoreboardMapper.toEntity(ScoreboardModel.fromMap(serverBoard));
      final model = ScoreboardMapper.fromEntity(entity);
      expect(model.players, {'ann': 3, 'bob': 5});
      expect(model.teams?.keys, ['Reds']);
    });
  });

  group('Access models', () {
    test('meta flags default to unprotected', () {
      final meta = AccessMetaModel.fromMap(const {'ownerId': 'uid-1'});
      expect(meta.readProtected, isFalse);
      expect(meta.writeProtected, isFalse);
      expect(meta.ownerProtected, isFalse);
      expect(meta.toMap()['ownerId'], 'uid-1');
    });

    test('secrets come from the entity hashes', () {
      final secrets = AccessMapper.secretsFromEntity(const AccessEntity(read: 'r', write: '', owner: null));
      expect(secrets, const AccessModel(read: 'r', write: ''));
    });

    test('toString does not leak hashes', () {
      expect(const AccessModel(read: 'secret-hash').toString(), isNot(contains('secret-hash')));
    });
  });
}
