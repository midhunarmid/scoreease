import 'package:scoreease/core/utils/security_helper.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/domain/repositories/score_board_repository.dart';

/// In-memory stand-in for the Firebase-backed repository.
class FakeScoreboardRepository implements ScoreboardRepository {
  final Map<String, ScoreboardEntity> boards = {};
  final Map<String, Map<AccessLevel, String>> passwords = {};
  final Set<String> grants = {};
  final List<String> revoked = [];

  void addBoard(ScoreboardEntity board, {Map<AccessLevel, String> passwords = const {}}) {
    boards[board.id!] = board;
    this.passwords[board.id!] = {
      for (final entry in passwords.entries) entry.key: SecurityHelper.hashPassword(entry.value),
    };
  }

  @override
  Future<bool> exists(String id) async => boards.containsKey(id);

  @override
  Future<ScoreboardEntity> getScoreboard(String id) async => boards[id]!;

  @override
  Future<String> createScoreboard(ScoreboardEntity scoreboardEntity) async {
    boards[scoreboardEntity.id!] = scoreboardEntity;
    return scoreboardEntity.id!;
  }

  @override
  Future<String> updateScoreboard(ScoreboardEntity scoreboardEntity) => createScoreboard(scoreboardEntity);

  @override
  Future<void> setPlayerScores(String id, Map<String, int> scores) async {
    final board = boards[id]!;
    boards[id] = board.copyWith(players: {...?board.players, ...scores});
  }

  @override
  Future<void> incrementPlayerScore(String id, String player, int delta) async {
    final board = boards[id]!;
    await setPlayerScores(id, {player: (board.players?[player] ?? 0) + delta});
  }

  @override
  Stream<ScoreboardEntity> getScoreboardStream(String id) => Stream.value(boards[id]!);

  @override
  Future<bool> hasAccess(String id, AccessLevel level) async =>
      passwords[id]?[level] == null || grants.contains('$id/${level.name}');

  @override
  Future<bool> unlock(String id, AccessLevel level, String passwordHash) async {
    final ok = passwords[id]?[level] == passwordHash;
    if (ok) grants.add('$id/${level.name}');
    return ok;
  }

  @override
  Future<void> revokeAccess(Iterable<String> ids) async {
    revoked.addAll(ids);
    grants.removeWhere((grant) => ids.any((id) => grant.startsWith('$id/')));
  }
}
