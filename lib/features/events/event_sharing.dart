import '../../data/cloud/access_remote.dart';
import '../../data/cloud/event_board_remote.dart';
import '../../data/cloud/live_board_remote.dart';
import '../../data/local/local_store.dart';

/// Keeps a shared event's cloud copy in step with this device: every game in
/// it gets a live board, so followers see all of them and open any of them.
class EventSharing {
  final LocalStore _store;
  final EventBoardRemote _events;
  final LiveBoardRemote _boards;

  EventSharing(this._store, this._events, this._boards);

  final _running = <String, Future<void>>{};
  final _again = <String>{};

  /// Shares event [meetId] and returns its code.
  Future<String> share(String meetId) async {
    final code = await _events.publish(_store.meet(meetId)!);
    await _store.saveMeet(_store.meet(meetId)!.copyWith(shareCode: code));
    await sync(meetId);
    return code;
  }

  /// Publishes games that aren't shared yet, then updates the event. One sync
  /// runs per event; asking during one runs another after it. A game that
  /// can't be published stays local and is tried again on the next sync.
  Future<void> sync(String meetId) {
    final running = _running[meetId];
    if (running != null) {
      _again.add(meetId);
      return running;
    }
    return _running[meetId] = _sync(meetId).whenComplete(() {
      _running.remove(meetId);
    });
  }

  Future<void> _sync(String meetId) async {
    do {
      _again.remove(meetId);
      final games = <String, String>{};
      for (final game in _store.gamesInMeet(meetId)) {
        var code = game.shareCode;
        if (code == null) {
          try {
            // Scoring stays with this device unless the owner sets a password.
            code = await _boards.publish(game, _store.events(game.id), writePassword: unknownPassword());
          } catch (_) {
            continue;
          }
          await _store.saveGame((_store.game(game.id) ?? game).copyWith(shareCode: code));
          final meet = _store.meet(meetId);
          if (meet != null) await _store.saveMeet(meet.copyWith(sharedBoards: [...meet.sharedBoards, code]));
        }
        games[game.id] = code;
      }
      final meet = _store.meet(meetId);
      if (meet?.shareCode != null) await _events.update(meet!.shareCode!, meet, games);
    } while (_again.contains(meetId));
  }

  /// Takes the event and the boards it published out of the cloud. The event
  /// and its games stay on this device.
  Future<void> stop(String meetId) async {
    final meet = _store.meet(meetId);
    final code = meet?.shareCode;
    if (meet == null || code == null) return;
    await _running[meetId];
    final boards = _store.meet(meetId)!.sharedBoards;
    await _events.unpublish(code, boards);
    for (final game in _store.gamesInMeet(meetId)) {
      if (boards.contains(game.shareCode)) await _store.saveGame(game.copyWith(clearShareCode: true));
    }
    await _store.saveMeet(_store.meet(meetId)!.copyWith(clearShare: true));
  }
}
