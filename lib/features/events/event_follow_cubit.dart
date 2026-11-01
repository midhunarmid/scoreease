import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/di.dart';
import '../../data/cloud/access_remote.dart';
import '../../data/cloud/cloud.dart';
import '../../data/cloud/event_board_remote.dart';
import '../../data/cloud/live_board_remote.dart';
import '../../engine/engine.dart';
import '../../engine/event_scoring.dart';
import '../../engine/meet.dart';

class EventFollowState {
  final Object? error;
  final MeetStandings? standings;

  /// Games shared with a view password, which this viewer can't read yet.
  final List<String> locked;

  const EventFollowState({this.error, this.standings, this.locked = const []});
}

/// Follows a shared event: listens to the event and to each of its games, and
/// scores it from them the way the owner's device does.
class EventFollowCubit extends Cubit<EventFollowState> {
  final String code;
  final EventBoardRemote _events;
  final LiveBoardRemote _boards;
  final AccessRemote _access;

  Meet? _meet;
  StreamSubscription<SharedEvent>? _eventSub;
  final _boardSubs = <String, StreamSubscription<LiveBoard>>{};
  final _snapshots = <String, GameSnapshot>{};
  final _locked = <String>{};

  /// Boards being listened to, or about to be.
  final _watched = <String>{};

  EventFollowCubit(this.code, {EventBoardRemote? events, LiveBoardRemote? boards, AccessRemote? access})
      : _events = events ?? getIt<EventBoardRemote>(),
        _boards = boards ?? getIt<LiveBoardRemote>(),
        _access = access ?? getIt<AccessRemote>(),
        super(const EventFollowState());

  Future<void> open() async {
    emit(const EventFollowState());
    await _eventSub?.cancel();
    _eventSub = _events.watch(code).listen(
          _onEvent,
          onError: (Object e) => emit(EventFollowState(error: isPermissionDenied(e) ? CloudException.eventNotFound : e)),
        );
  }

  void _onEvent(SharedEvent event) {
    _meet = event.meet;
    final boards = event.boards.toSet();
    _watched.difference(boards).toList().forEach(_stopWatching);
    _locked.retainAll(boards);
    boards.difference(_watched).difference(_locked).forEach(_watchBoard);
    _update();
  }

  Future<void> _watchBoard(String board) async {
    _watched.add(board);
    final meta = await _access.getMeta(board).catchError((Object _) => null);
    if (meta == null || isClosed || !_watched.contains(board)) return;
    _boardSubs[board] = _boards.watch(board, meta).listen(
      (live) {
        _snapshots[board] = GameEngine.compute(live.game, live.events);
        _update();
      },
      onError: (Object e) {
        _stopWatching(board);
        if (e == CloudException.accessDenied) _locked.add(board);
        _update();
      },
    );
  }

  void _stopWatching(String board) {
    _watched.remove(board);
    _boardSubs.remove(board)?.cancel();
    _snapshots.remove(board);
  }

  /// Tries the locked games again, after a password was entered.
  void retryLocked() {
    final boards = _locked.toList();
    _locked.clear();
    boards.forEach(_watchBoard);
  }

  void _update() {
    final meet = _meet;
    if (meet != null) emit(EventFollowState(standings: scoreMeet(meet, _snapshots.values.toList()), locked: _locked.toList()));
  }

  @override
  void emit(EventFollowState state) {
    if (!isClosed) super.emit(state);
  }

  @override
  Future<void> close() async {
    await _eventSub?.cancel();
    for (final sub in _boardSubs.values) {
      await sub.cancel();
    }
    return super.close();
  }
}
