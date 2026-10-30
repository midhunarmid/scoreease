import 'engine.dart';

/// Rally scoring for two sides in sets: table tennis, badminton, volleyball,
/// pickleball...
///
/// Settings: `points` (to win a set), `winBy` (lead needed, default 2), `cap`
/// (points at which the next point wins regardless), `sets` (sets needed to
/// win the match), `decidingPoints` (points in the deciding set),
/// `serveEvery` (0 = rally winner serves, n = serve changes every n points),
/// `courts` (`badminton` = track service courts and, in doubles, who serves
/// to whom; the game winner serves first in the next game).
class SetsState {
  /// Finished sets as [side A points, side B points].
  final List<List<int>> sets;
  final List<int> current;

  /// 0 or 1: who serves next.
  final int server;

  /// Who served first in the current set.
  final int setFirstServer;

  /// Doubles: for each side, the slot standing in the right service court.
  /// The partner is in the left. A substitute takes over the slot of the
  /// player they replace.
  final List<int> rightCourt;

  const SetsState({
    this.sets = const [],
    this.current = const [0, 0],
    this.server = 0,
    this.setFirstServer = 0,
    this.rightCourt = const [0, 0],
  });

  SetsState copyWith({List<List<int>>? sets, List<int>? current, int? server, int? setFirstServer, List<int>? rightCourt}) => SetsState(
        sets: sets ?? this.sets,
        current: current ?? this.current,
        server: server ?? this.server,
        setFirstServer: setFirstServer ?? this.setFirstServer,
        rightCourt: rightCourt ?? this.rightCourt,
      );

  int setsWon(int side) => sets.where((s) => s[side] > s[1 - side]).length;

  /// The server serves from the right court on an even score, else the left.
  bool get serveFromRight => current[server].isEven;

  /// Court slot of [side]'s player in the right or left court.
  int memberIn(int side, {required bool right}) => right ? rightCourt[side] : 1 - rightCourt[side];

  /// Doubles: the member serving, and the one diagonally opposite receiving.
  int get serverMember => memberIn(server, right: serveFromRight);
  int get receiverMember => memberIn(1 - server, right: serveFromRight);
}

class SetsEngine extends ScoringEngine<SetsState> {
  const SetsEngine();

  /// Point to a side: `{p: pid}`.
  static const point = 'point';

  /// Change who serves: `{p: pid}`. In doubles also `m` (serving court slot)
  /// and `r` (receiving slot of the other side).
  static const serve = 'serve';

  /// Doubles: swap the two players of a side between courts: `{p: pid}`.
  /// Fixes a service court error without touching the score.
  static const positions = 'positions';

  /// Badminton service rules: courts by score, positions in doubles.
  static bool tracksCourts(Game game) =>
      (game.stringSetting('courts') ?? (game.templateId == 'badminton' ? 'badminton' : null)) == 'badminton';

  /// Two players a side, so the app can say who serves to whom.
  static bool isDoubles(Game game) =>
      tracksCourts(game) && game.participants.length >= 2 && game.participants.take(2).every((p) => p.onCourt.length == 2);

  /// "Ann → Dee · right court", or for singles "Ann · serve from right".
  static String serveLine(SetsState state, Game game) {
    final court = state.serveFromRight ? 'right' : 'left';
    final server = game.participants[state.server];
    if (!isDoubles(game)) return '${server.name} · serve from $court';
    final receiver = game.participants[1 - state.server];
    return '${server.playerIn(state.serverMember)} → ${receiver.playerIn(state.receiverMember)} · $court court';
  }

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
  bool fixedTeams(Game game) => tracksCourts(game);

  @override
  SetsState initial(Game game) {
    final first = game.intSetting('firstServer') ?? 0;
    return SetsState(server: first, setFirstServer: first);
  }

  @override
  SetsState apply(SetsState state, ScoreEvent e, Game game) {
    final side = _sideOf(game, e.get<String>('p'));
    if (side < 0) return state;
    final courts = tracksCourts(game);
    if (e.type == serve) {
      final fresh = state.current[0] + state.current[1] == 0;
      var next = state.copyWith(server: side, setFirstServer: fresh ? side : null);
      final m = e.get<num>('m')?.toInt(), r = e.get<num>('r')?.toInt();
      if (courts && (m != null || r != null)) {
        // Put the chosen server and receiver in the court the score calls for.
        final right = next.serveFromRight;
        final rightCourt = [...next.rightCourt];
        if (m == 0 || m == 1) rightCourt[side] = right ? m! : 1 - m!;
        if (r == 0 || r == 1) rightCourt[1 - side] = right ? r! : 1 - r!;
        next = next.copyWith(rightCourt: rightCourt);
      }
      return next;
    }
    if (e.type == positions) {
      return state.copyWith(rightCourt: [for (var i = 0; i < 2; i++) i == side ? 1 - state.rightCourt[i] : state.rightCourt[i]]);
    }
    if (e.type != point) return state;

    final current = [...state.current];
    current[side]++;
    if (setWon(current, side, game, state)) {
      // Badminton: the game winner serves first in the next. Otherwise the
      // side that received first in this set does.
      final nextFirst = courts ? side : 1 - state.setFirstServer;
      return state.copyWith(sets: [...state.sets, current], current: const [0, 0], server: nextFirst, setFirstServer: nextFirst);
    }

    // Badminton: the serving side scores and its players switch courts.
    final rightCourt = courts && side == state.server
        ? [for (var i = 0; i < 2; i++) i == side ? 1 - state.rightCourt[i] : state.rightCourt[i]]
        : state.rightCourt;

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
    return state.copyWith(current: current, server: server, rightCourt: rightCourt);
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
        serve => _describeServe(e, game),
        positions => '${game.nameOf(e.get<String>('p') ?? '')} switched courts',
        _ => e.type,
      };

  String _describeServe(ScoreEvent e, Game game) {
    final side = _sideOf(game, e.get<String>('p'));
    final m = e.get<num>('m')?.toInt(), r = e.get<num>('r')?.toInt();
    if (side < 0 || m == null || r == null || !isDoubles(game)) return '${game.nameOf(e.get<String>('p') ?? '')} to serve';
    if (m < 0 || m > 1 || r < 0 || r > 1) return '${game.nameOf(e.get<String>('p') ?? '')} to serve';
    return '${game.participants[side].playerIn(m)} serves to ${game.participants[1 - side].playerIn(r)}';
  }
}
