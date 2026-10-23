import 'engine.dart';

/// Limited-overs cricket between two sides, one innings each. Team totals
/// only (runs, wickets, overs, extras), which is what casual games need.
///
/// Settings: `overs` (int), `wickets` (int, default 10), `battingFirst`
/// (0 or 1), `wideRuns` / `noBallRuns` (penalty runs, default 1).
class Innings {
  final int side;
  final int runs;
  final int wickets;
  final int legalBalls;
  final int extras;

  /// Labels for every delivery, e.g. ["1", "•", "4", "Wd", "W"].
  final List<String> deliveries;

  /// How many entries of [deliveries] came before the current over.
  final int overStart;
  final bool closed;

  const Innings({
    required this.side,
    this.runs = 0,
    this.wickets = 0,
    this.legalBalls = 0,
    this.extras = 0,
    this.deliveries = const [],
    this.overStart = 0,
    this.closed = false,
  });

  List<String> get currentOver => deliveries.sublist(overStart);
  String get overs => formatOvers(legalBalls);
  String get scoreLine => '$runs/$wickets';

  Innings copyWith({int? runs, int? wickets, int? legalBalls, int? extras, List<String>? deliveries, int? overStart, bool? closed}) =>
      Innings(
        side: side,
        runs: runs ?? this.runs,
        wickets: wickets ?? this.wickets,
        legalBalls: legalBalls ?? this.legalBalls,
        extras: extras ?? this.extras,
        deliveries: deliveries ?? this.deliveries,
        overStart: overStart ?? this.overStart,
        closed: closed ?? this.closed,
      );
}

String formatOvers(int balls) => '${balls ~/ 6}.${balls % 6}';

class CricketState {
  final List<Innings> innings;
  const CricketState(this.innings);

  Innings get current => innings.last;
  Innings? get first => innings.isNotEmpty ? innings.first : null;
  bool get isChase => innings.length == 2;

  /// Runs the side batting second needs to win.
  int? get target => isChase ? innings.first.runs + 1 : null;

  Innings? inningsOf(int side) {
    for (final i in innings) {
      if (i.side == side) return i;
    }
    return null;
  }
}

class CricketEngine extends ScoringEngine<CricketState> {
  const CricketEngine();

  /// A delivery: `{r: runs, x: '' | 'wd' | 'nb' | 'b' | 'lb', w: wicket}`.
  static const ball = 'ball';

  /// Closes the current innings early (declared / all out by hand).
  static const endInnings = 'endInnings';

  static int maxOvers(Game game) => game.intSetting('overs') ?? 6;
  static int maxWickets(Game game) => game.intSetting('wickets') ?? 10;

  @override
  CricketState initial(Game game) => CricketState([Innings(side: game.intSetting('battingFirst') ?? 0)]);

  static String label(int runs, String extra, bool wicket) {
    final base = switch (extra) {
      'wd' => runs > 0 ? '${runs}Wd' : 'Wd',
      'nb' => runs > 0 ? '${runs}Nb' : 'Nb',
      'b' => '${runs}B',
      'lb' => '${runs}Lb',
      _ => runs == 0 ? '•' : '$runs',
    };
    if (!wicket) return base;
    return base == '•' ? 'W' : '$base+W';
  }

  bool _inningsOver(Innings i, CricketState state, Game game) {
    if (i.closed) return true;
    if (i.wickets >= maxWickets(game)) return true;
    if (i.legalBalls >= maxOvers(game) * 6) return true;
    final target = state.target;
    return state.isChase && target != null && i.runs >= target;
  }

  CricketState _closeIfDone(CricketState state, Game game) {
    final cur = state.current;
    if (!_inningsOver(cur, state, game)) return state;
    final closed = [...state.innings]..[state.innings.length - 1] = cur.copyWith(closed: true);
    if (closed.length == 1) closed.add(Innings(side: 1 - cur.side));
    return CricketState(closed);
  }

  @override
  CricketState apply(CricketState state, ScoreEvent e, Game game) {
    var cur = state.current;
    if (e.type == endInnings) {
      return _closeIfDone(CricketState([...state.innings]..[state.innings.length - 1] = cur.copyWith(closed: true)), game);
    }
    if (e.type != ball) return state;

    final runs = e.intOf('r').clamp(0, 7);
    final extra = e.get<String>('x') ?? '';
    final wicket = e.get<bool>('w') ?? false;
    final legal = extra != 'wd' && extra != 'nb';
    final penalty = switch (extra) {
      'wd' => game.intSetting('wideRuns') ?? 1,
      'nb' => game.intSetting('noBallRuns') ?? 1,
      _ => 0,
    };
    final extraRuns = penalty + (extra == 'b' || extra == 'lb' || extra == 'wd' ? runs : 0);

    final deliveries = [...cur.deliveries, label(runs, extra, wicket)];
    final legalBalls = cur.legalBalls + (legal ? 1 : 0);
    cur = cur.copyWith(
      runs: cur.runs + runs + penalty,
      extras: cur.extras + extraRuns,
      wickets: cur.wickets + (wicket ? 1 : 0),
      legalBalls: legalBalls,
      deliveries: deliveries,
      // A new over starts after every sixth legal ball.
      overStart: legal && legalBalls % 6 == 0 ? deliveries.length : cur.overStart,
    );
    return _closeIfDone(CricketState([...state.innings]..[state.innings.length - 1] = cur), game);
  }

  @override
  bool isFinished(CricketState state, Game game) => state.innings.length == 2 && state.innings[1].closed;

  @override
  List<Standing> standings(CricketState state, Game game) {
    final rows = <Standing>[];
    for (var side = 0; side < 2 && side < game.participants.length; side++) {
      final inn = state.inningsOf(side);
      rows.add(Standing(
        participantId: game.participants[side].id,
        score: inn?.runs ?? 0,
        detail: inn == null ? 'Yet to bat' : '${inn.scoreLine} (${inn.overs})',
      ));
    }
    return rankStandings(rows);
  }

  @override
  List<String> winners(CricketState state, Game game, List<Standing> standings) {
    if (state.innings.length < 2 || game.participants.length < 2) return const [];
    final a = state.innings[0], b = state.innings[1];
    if (a.runs == b.runs) return const [];
    return [game.participants[a.runs > b.runs ? a.side : b.side].id];
  }

  @override
  String resultText(CricketState state, Game game, List<String> winners, List<Standing> standings) {
    if (state.innings.length < 2) return 'Match abandoned';
    final a = state.innings[0], b = state.innings[1];
    if (a.runs == b.runs) return 'Match tied';
    if (b.runs > a.runs) {
      final left = maxWickets(game) - b.wickets;
      return '${game.participants[b.side].name} won by $left wicket${left == 1 ? '' : 's'}';
    }
    final margin = a.runs - b.runs;
    return '${game.participants[a.side].name} won by $margin run${margin == 1 ? '' : 's'}';
  }

  @override
  String summary(CricketState state, Game game, List<Standing> standings) => state.innings
      .where((i) => i.side < game.participants.length)
      .map((i) => '${game.participants[i.side].name} ${i.scoreLine} (${i.overs})')
      .join(' · ');

  @override
  String describe(ScoreEvent e, Game game) {
    if (e.type == endInnings) return 'Innings closed';
    final l = label(e.intOf('r'), e.get<String>('x') ?? '', e.get<bool>('w') ?? false);
    return 'Ball: ${l == '•' ? 'dot' : l}';
  }
}
