import 'package:firebase_database/firebase_database.dart';

import '../../engine/meet.dart';
import 'access_remote.dart';
import 'cloud.dart';
import 'live_board_remote.dart';

/// A shared event as it is in the cloud.
class SharedEvent {
  final Meet meet;

  /// The share code of each of its games.
  final List<String> boards;

  const SharedEvent(this.meet, this.boards);
}

/// Shared events live under `eventBoards/{code}`: the event's name and teams,
/// and `games/{gameId}` pointing at each game's board. Its scores are not
/// stored here. Followers read the boards and work them out, as the owner's
/// device does from its own games.
class EventBoardRemote {
  static const root = 'eventBoards';

  FirebaseDatabase get _db => Cloud.db;

  /// Uploads an event with no games yet and returns its share code.
  Future<String> publish(Meet meet) async {
    await Cloud.ensureReady();
    final uid = Cloud.uid;
    if (uid == null) throw CloudException.offline;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = LiveBoardRemote.newCode();
      try {
        await _db.ref().update({
          '${AccessRemote.meta}/$code': AccessMeta(ownerId: uid).toMap(),
          '$root/$code': meet.toShareJson(),
        });
        return code;
      } catch (e) {
        // A taken code is rejected by the rules; try another one.
        if (!isPermissionDenied(e)) rethrow;
      }
    }
    throw const CloudException('Couldn\'t share', 'Please try again in a moment.');
  }

  /// Owner only: replaces the event with [meet] and [games] (game id → code).
  Future<void> update(String code, Meet meet, Map<String, String> games) async {
    await Cloud.ensureReady();
    await _db.ref('$root/$code').set({...meet.toShareJson(), 'games': games});
  }

  /// Owner only: removes the event and [boards] from the cloud.
  Future<void> unpublish(String code, Iterable<String> boards) async {
    await Cloud.ensureReady();
    await _db.ref().update({
      for (final id in [code, ...boards]) ...{
        '${AccessRemote.secrets}/$id': null,
        '${AccessRemote.meta}/$id': null,
      },
      '$root/$code': null,
      for (final board in boards) '${LiveBoardRemote.root}/$board': null,
    });
  }

  /// Whether [code] is an event rather than a game.
  Future<bool> exists(String code) async {
    await Cloud.ensureReady();
    return (await _db.ref('$root/$code/name').get()).exists;
  }

  /// Streams the event. Errors with [CloudException.eventNotFound] when it's
  /// gone.
  Stream<SharedEvent> watch(String code) async* {
    await Cloud.ensureReady();
    yield* _db.ref('$root/$code').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) throw CloudException.eventNotFound;
      final games = value['games'];
      return SharedEvent(Meet.fromShareJson(code, value), games is Map ? [for (final c in games.values) c.toString()] : const []);
    });
  }
}
