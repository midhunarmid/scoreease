import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/di.dart';
import '../../data/cloud/access_remote.dart';
import '../../data/cloud/cloud.dart';
import '../../data/cloud/live_board_remote.dart';
import '../../data/local/local_store.dart';
import '../../data/local/settings_store.dart';
import '../../engine/counter_engine.dart';
import '../../engine/engine.dart';

class PlayState {
  final bool loading;
  final Object? error;
  final GameSnapshot? snapshot;

  /// Set when a password is needed before the game can be shown or scored.
  final AccessLevel? needsPassword;

  /// Whether this device may add events.
  final bool canScore;

  /// The game is shared live (owner or joined).
  final String? liveCode;

  const PlayState({
    this.loading = true,
    this.error,
    this.snapshot,
    this.needsPassword,
    this.canScore = false,
    this.liveCode,
  });

  Game? get game => snapshot?.game;
  bool get isOwner => game?.isOwner ?? false;

  PlayState copyWith({
    bool? loading,
    Object? error,
    bool clearError = false,
    GameSnapshot? snapshot,
    AccessLevel? needsPassword,
    bool clearPassword = false,
    bool? canScore,
    String? liveCode,
    bool clearLive = false,
  }) =>
      PlayState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        snapshot: snapshot ?? this.snapshot,
        needsPassword: clearPassword ? null : (needsPassword ?? this.needsPassword),
        canScore: canScore ?? this.canScore,
        liveCode: clearLive ? null : (liveCode ?? this.liveCode),
      );
}

/// Runs one game: local, shared by this device, or joined from a link.
/// The same cubit backs the scoring screen, the live viewer and TV mode.
class PlayCubit extends Cubit<PlayState> {
  final LocalStore _store;
  final LiveBoardRemote _remote;
  final AccessRemote _access;
  final SettingsStore _settings;

  /// Id of the copy kept on this device, if any.
  String? _localId;
  Game? _game;
  List<ScoreEvent> _events = [];
  StreamSubscription<LiveBoard>? _liveSub;
  String? _code;
  AccessLevel _level = AccessLevel.read;
  bool _wasFinished = false;

  /// A counter score shown here but not sent yet, while taps keep coming.
  ScoreEvent? _burst;
  Timer? _burstTimer;

  /// Taps on the same side closer together than this become one event.
  static const burstWindow = Duration(milliseconds: 1500);

  /// Fires once when the game ends, for the celebration.
  final _finished = StreamController<GameSnapshot>.broadcast();
  Stream<GameSnapshot> get onFinished => _finished.stream;

  /// Errors from actions (e.g. a failed sync) that don't replace the screen.
  final _errors = StreamController<Object>.broadcast();
  Stream<Object> get actionErrors => _errors.stream;

  PlayCubit({LocalStore? store, LiveBoardRemote? remote, AccessRemote? access, SettingsStore? settings})
      : _store = store ?? getIt<LocalStore>(),
        _remote = remote ?? getIt<LiveBoardRemote>(),
        _access = access ?? getIt<AccessRemote>(),
        _settings = settings ?? getIt<SettingsStore>(),
        super(const PlayState());

  // ---- Start ----

  Future<void> openLocal(String gameId) async {
    final game = _store.game(gameId);
    if (game == null) {
      emit(state.copyWith(loading: false, error: const CloudException('Game not found', 'It may have been deleted.')));
      return;
    }
    _localId = gameId;
    _game = game;
    _events = _store.events(gameId);
    _wasFinished = game.isFinished;
    _emitSnapshot(canScore: true);
    if (game.shareCode != null && game.isOwner) {
      // Keep the shared copy in sync. Local scoring still works if the
      // network is down; Firebase queues the writes.
      unawaited(_goLive(game.shareCode!, AccessLevel.owner, quiet: true));
    }
  }

  /// Opens a game someone shared. [level] is read for viewers, write for
  /// co-scorers.
  Future<void> openLive(String code, AccessLevel level) async {
    _code = code;
    _level = level;
    final mine = _store.gameByShareCode(code);
    if (mine != null && mine.isOwner) {
      await openLocal(mine.id);
      return;
    }
    _localId = LiveBoardRemote.liveGameId(code);
    await _goLive(code, level);
  }

  Future<void> _goLive(String code, AccessLevel level, {bool quiet = false}) async {
    _code = code;
    try {
      final meta = await _access.getMeta(code);
      if (meta == null) {
        if (quiet) {
          // The cloud copy is gone; carry on locally.
          await _saveLocal(_game!.copyWith(clearShareCode: true));
          _emitSnapshot(canScore: true);
          return;
        }
        throw CloudException.notFound;
      }
      final allowed = await _access.hasAccess(code, level == AccessLevel.owner ? AccessLevel.write : level, known: meta);
      if (!allowed) {
        if (!quiet) emit(state.copyWith(loading: false, needsPassword: level, liveCode: code));
        return;
      }
      final canScore = level != AccessLevel.read || await _access.hasAccess(code, AccessLevel.write, known: meta);
      await _liveSub?.cancel();
      _liveSub = _remote.watch(code, meta).listen(
        (board) {
          final local = _localId == null ? null : _store.game(_localId!);
          _game = local != null && local.isOwner
              ? local.copyWith(title: board.game.title, participants: board.game.participants, settings: board.game.settings)
              : board.game;
          final burst = _burst;
          _events = [...board.events, if (burst != null && board.events.every((e) => e.id != burst.id)) burst];
          _emitSnapshot(canScore: canScore, liveCode: code);
          _persist();
        },
        onError: (Object e) {
          if (quiet) return;
          emit(state.copyWith(loading: false, error: e));
        },
      );
    } catch (e) {
      if (!quiet) emit(state.copyWith(loading: false, error: e));
    }
  }

  Future<bool> unlock(String password) async {
    final level = state.needsPassword ?? _level;
    final ok = await _access.unlock(_code!, level, password);
    if (!ok) return false;
    _settings.unlockedBoards = {..._settings.unlockedBoards, _code!}.toList();
    emit(state.copyWith(clearPassword: true, loading: true));
    await _goLive(_code!, _level);
    return true;
  }

  // ---- Scoring ----

  /// Records an event and returns its id (null when scoring isn't allowed).
  Future<String?> add(String type, [Map<String, dynamic> data = const {}]) => _record(type, data);

  /// Adds counter points for [pid]. Quick taps on the same side add up into
  /// one event, so the log and "who scored" see one +5 instead of five +1s.
  /// The score shows here at once and reaches others when the taps stop.
  Future<String?> addPoints(String pid, int v) async {
    final open = _burst;
    final merge = open != null && open.get<String>('p') == pid && open.intOf('v').sign == v.sign;
    if (!merge || !state.canScore || (state.snapshot?.finished ?? false)) {
      return _record(CounterEngine.add, {'p': pid, 'v': v}, burst: true);
    }
    if (_settings.haptics) HapticFeedback.selectionClick();
    final merged = ScoreEvent(id: open.id, type: open.type, data: {'p': pid, 'v': open.intOf('v') + v}, ts: open.ts, by: open.by);
    _burst = merged;
    _events = [for (final e in _events) e.id == open.id ? merged : e];
    _emitSnapshot();
    _persist();
    _burstTimer?.cancel();
    _burstTimer = Timer(burstWindow, flushBurst);
    return open.id;
  }

  /// Sends the score still gathering taps, if any.
  void flushBurst() {
    _burstTimer?.cancel();
    _burstTimer = null;
    final event = _burst;
    _burst = null;
    if (event != null) unawaited(_send(event));
  }

  Future<String?> _record(String type, Map<String, dynamic> data, {bool burst = false}) async {
    if (!state.canScore || _game == null) return null;
    flushBurst();
    if (_settings.haptics) HapticFeedback.selectionClick();
    final now = DateTime.now().millisecondsSinceEpoch;
    final event = ScoreEvent(id: PushId.next(now), type: type, data: data, ts: now, by: Cloud.uid ?? 'local');
    _events = [..._events, event];
    _emitSnapshot();
    _persist();
    if (burst) {
      _burst = event;
      _burstTimer = Timer(burstWindow, flushBurst);
    } else {
      await _send(event);
    }
    return event.id;
  }

  Future<void> _send(ScoreEvent event) async {
    if (state.liveCode == null) return;
    try {
      await _remote.addEvent(state.liveCode!, event);
    } catch (e) {
      if (!_errors.isClosed) _errors.add(e);
    }
  }

  /// Undoes the last score. Tags aren't undone on their own: they go with
  /// the score they belong to, and can be changed from the log.
  Future<void> undo() async {
    final last = state.snapshot?.effective.lastWhereOrNull((e) => e.type != EventTypes.tag);
    if (last != null) await add(EventTypes.undo, {'target': last.id});
  }

  /// Credits team [members] (indexes) with scoring event [target].
  Future<void> tag(String target, Set<int> members) async {
    final current = state.snapshot?.tags[target] ?? const <int>{};
    if (current.length == members.length && current.containsAll(members)) return;
    await add(EventTypes.tag, tagData(target, members.toList()..sort()));
  }

  Future<void> redo() async {
    final target = state.snapshot?.redoTarget;
    if (target != null) await add(EventTypes.redo, {'target': target});
  }

  Future<void> endGame() async {
    await add(EventTypes.end);
  }

  // ---- Owner actions ----

  Future<void> updateGame(Game game) async {
    _game = game.copyWith(updatedAt: DateTime.now());
    _emitSnapshot();
    await _saveLocal(_game!);
    if (state.liveCode != null && game.isOwner) await _remote.updateMeta(state.liveCode!, _game!);
  }

  Future<String> share({String readPassword = '', String writePassword = ''}) async {
    // Published with the rest of the log; sending it again would be refused.
    flushBurst();
    final code = await _remote.publish(_game!, _events, readPassword: readPassword, writePassword: writePassword);
    _game = _game!.copyWith(shareCode: code);
    await _saveLocal(_game!);
    _emitSnapshot(liveCode: code);
    await _goLive(code, AccessLevel.owner, quiet: true);
    return code;
  }

  Future<void> stopSharing() async {
    final code = state.liveCode;
    if (code == null) return;
    flushBurst();
    await _liveSub?.cancel();
    _liveSub = null;
    await _remote.unpublish(code);
    _game = _game!.copyWith(clearShareCode: true);
    await _saveLocal(_game!);
    emit(state.copyWith(clearLive: true));
    _emitSnapshot();
  }

  Future<void> setPasswords({String? read, String? write}) => _remote.setPasswords(state.liveCode!, read: read, write: write);

  // ---- Internals ----

  void _emitSnapshot({bool? canScore, String? liveCode}) {
    final game = _game;
    if (game == null) return;
    final snapshot = GameEngine.compute(game, _events);
    emit(state.copyWith(loading: false, snapshot: snapshot, canScore: canScore, liveCode: liveCode, clearError: true, clearPassword: true));
    if (snapshot.finished && !_wasFinished && !_finished.isClosed) _finished.add(snapshot);
    _wasFinished = snapshot.finished;
  }

  Future<void> _saveLocal(Game game) async {
    if (_localId == null) return;
    await _store.saveGame(game);
  }

  /// Keeps the device copy (and its summary for lists) up to date.
  Future<void> _persist() async {
    final snapshot = state.snapshot;
    final localId = _localId;
    if (snapshot == null || localId == null) return;
    final game = snapshot.game;
    await _store.saveGame(Game(
      id: localId,
      title: game.title,
      templateId: game.templateId,
      mode: game.mode,
      settings: game.settings,
      participants: game.participants,
      createdAt: game.createdAt,
      updatedAt: DateTime.now(),
      status: snapshot.finished ? GameStatus.finished : GameStatus.active,
      winners: snapshot.winners,
      summary: snapshot.summary,
      shareCode: game.shareCode,
      isOwner: game.isOwner,
      memberPoints: snapshot.memberPointsByName,
    ));
    await _store.saveEvents(localId, _events);
  }

  @override
  void emit(PlayState state) {
    if (!isClosed) super.emit(state);
  }

  @override
  Future<void> close() async {
    flushBurst();
    await _liveSub?.cancel();
    await _finished.close();
    await _errors.close();
    return super.close();
  }
}
