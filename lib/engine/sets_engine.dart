import 'engine.dart';

/// Rally scoring for two sides in sets: table tennis, badminton, volleyball,
/// pickleball...
///
/// Settings: `points` (to win a set), `winBy` (lead needed, default 2), `cap`
/// (points at which the next point wins regardless), `sets` (sets needed to
/// win the match), `decidingPoints` (points in the deciding set),
/// `serveEvery` (0 = rally winner serves, n = serve changes every n points).
class SetsState {
  /// Finished sets as [side A points, side B points].
  final List<List<int>> sets;
  final List<int> current;

  /// 0 or 1: who serves next.
  final int server;

  /// Who served first in the current set.
  final int setFirstServer;

  const SetsState({this.sets = const [], this.current = const [0, 0], this.server = 0, this.setFirstServer = 0});

  int setsWon(int side) => sets.where((s) => s[side] > s[1 - side]).length;
}

class SetsEngine extends ScoringEngine<SetsState> {
  const SetsEngine();

  /// Point to a side: `{p: pid}`.
  static const point = 'point';

  /// Change who serves: `{p: pid}`.
  static const serve = 'serve';

  static int setsToWin(Game game) => game.intSetting('sets') ?? 2;

  static bool isDecidingSet(SetsState state, Game game) {
    final need = setsToWin(game);
    return state.setsWon(0) == need - 1 && state.setsWon(1) == need - 1;
  }

  static int pointsForSet(SetsState state, Game game) {
    final deciding = game.intSetting('decidingPoints');
    if (deciding != null && deciding > 0 && isDecidingSet(state, game)) return deciding;
    return game.intSetting('points') ?? 11;
  }

  static bool setWon(List<int> score, int side, Game game, SetsState state) {
    final target = pointsForSet(state, game);
    final winBy = game.intSetting('winBy') ?? 2;
    final cap = game.intSetting('cap');
    final mine = score[side], theirs = score[1 - side];
    if (cap != null && cap > 0 && mine >= cap) return true;
    return mine >= target && mine - theirs >= winBy;
  }

  int _sideOf(Game game, String? pid) {
    if (game.participants.length < 2 || pid == null) return -1;
    if (pid == game.participants[0].id) return 0;
    if (pid == game.participants[1].id) return 1;
    return -1;
  }

  @override
  SetsState initial(Game game) {
    final first = game.intSetting('firstServer') ?? 0;
    return SetsState(server: first, setFirstServer: first);
  }

  @override
  SetsState apply(SetsState state, ScoreEvent e, Game game) {
    final side = _sideOf(game, e.get<String>('p'));
    if (side < 0) return state;
    if (e.type == serve) {
      return state.current[0] + state.current[1] == 0
          ? SetsState(sets: state.sets, current: state.current, server: side, setFirstServer: side)
          : SetsState(sets: state.sets, current: state.current, server: side, setFirstServer: state.setFirstServer);
    }
    if (e.type != point) return state;

    final current = [...state.current];
    current[side]++;
    if (setWon(current, side, game, state)) {
      // The side that received first in this set serves first in the next.
      final nextFirst = 1 - state.setFirstServer;
      return SetsState(sets: [...state.sets, current], current: const [0, 0], server: nextFirst, setFirstServer: nextFirst);
    }

    final every = game.intSetting('serveEvery') ?? 0;
    int server;
    if (every <= 0) {
      server = side;
    } else {
      final played = current[0] + current[1];
      final target = pointsForSet(state, game);
      final deuceFrom = (target - 1) * 2;
      final changes = played >= deuceFrom ? (deuceFrom ~/ every) + (played - deuceFrom) : played ~/ every;
      server = changes.isEven ? state.setFirstServer : 1 - state.setFirstServer;
    }
    return SetsState(sets: state.sets, current: current, server: server, setFirstServer: state.setFirstServer);
  }

  @override
  bool isFinished(SetsState state, Game game) {
    final need = setsToWin(game);
    return state.setsWon(0) >= need || state.setsWon(1) >= need;
  }

  @override
  List<Standing> standings(SetsState state, Game game) {
    final rows = <Standing>[];
    for (var i = 0; i < game.participants.length && i < 2; i++) {
      rows.add(Standing(
        participantId: game.participants[i].id,
        score: state.setsWon(i),
        detail: 'Points ${state.current[i]}',
      ));
    }
    return rankStandings(rows, tieBreak: (a, b) {
      final ia = _sideOf(game, a.participantId), ib = _sideOf(game, b.participantId);
      return state.current[ib].compareTo(state.current[ia]);
    });
  }

  @override
  List<String> winners(SetsState state, Game game, List<Standing> standings) {
    if (game.participants.length < 2) return const [];
    final a = state.setsWon(0), b = state.setsWon(1);
    if (a == b) return const [];
    return [game.participants[a > b ? 0 : 1].id];
  }

  @override
  String resultText(SetsState state, Game game, List<String> winners, List<Standing> standings) {
    if (winners.isEmpty) return 'Match drawn';
    final winSide = _sideOf(game, winners.first);
    final scores = state.sets.map((s) => '${s[winSide]}-${s[1 - winSide]}').join(', ');
    return '${game.nameOf(winners.first)} wins ${state.setsWon(winSide)}-${state.setsWon(1 - winSide)} ($scores)';
  }

  @override
  String summary(SetsState state, Game game, List<Standing> standings) {
    if (game.participants.length < 2) return '';
    final a = game.participants[0].name, b = game.participants[1].name;
    return '$a ${state.setsWon(0)}–${state.setsWon(1)} $b · ${state.current[0]}–${state.current[1]}';
  }

  @override
  Credit? creditable(ScoreEvent event, Game game) {
    final pid = event.get<String>('p');
    return event.type == point && pid != null && _sideOf(game, pid) >= 0 ? (pid: pid, v: 1) : null;
  }

  @override
  String describe(ScoreEvent e, Game game) => switch (e.type) {
        point => 'Point ${game.nameOf(e.get<String>('p') ?? '')}',
        serve => '${game.nameOf(e.get<String>('p') ?? '')} to serve',
        _ => e.type,
      };
}
