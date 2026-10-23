import 'engine.dart';

/// Free-form +/- scoring with an optional target and match clock.
///
/// Settings: `lowWins` (bool), `target` (int), `steps` ("1,2,3"),
/// `periods` (int), `periodMinutes` (int).
class CounterState {
  final Map<String, int> scores;

  /// Match clock: whether it is running, since when, and time banked before.
  final bool clockRunning;
  final int clockStartedAt;
  final int clockBankedMs;
  final int period;

  const CounterState({
    required this.scores,
    this.clockRunning = false,
    this.clockStartedAt = 0,
    this.clockBankedMs = 0,
    this.period = 1,
  });

  int elapsedMs(int now) => clockBankedMs + (clockRunning && now > clockStartedAt ? now - clockStartedAt : 0);

  CounterState copyWith({Map<String, int>? scores, bool? clockRunning, int? clockStartedAt, int? clockBankedMs, int? period}) =>
      CounterState(
        scores: scores ?? this.scores,
        clockRunning: clockRunning ?? this.clockRunning,
        clockStartedAt: clockStartedAt ?? this.clockStartedAt,
        clockBankedMs: clockBankedMs ?? this.clockBankedMs,
        period: period ?? this.period,
      );
}

class CounterEngine extends ScoringEngine<CounterState> {
  const CounterEngine();

  static const add = 'add';
  static const set = 'set';
  static const clock = 'clock';
  static const nextPeriod = 'period';

  static List<int> stepsOf(Game game) {
    final raw = game.stringSetting('steps') ?? '1';
    final steps = raw.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().where((s) => s > 0).toList();
    return steps.isEmpty ? const [1] : steps;
  }

  @override
  CounterState initial(Game game) => CounterState(scores: {for (final p in game.participants) p.id: 0});

  @override
  CounterState apply(CounterState state, ScoreEvent e, Game game) {
    switch (e.type) {
      case add:
      case set:
        final pid = e.get<String>('p');
        if (pid == null || !state.scores.containsKey(pid)) return state;
        final scores = Map<String, int>.from(state.scores);
        scores[pid] = e.type == add ? scores[pid]! + e.intOf('v') : e.intOf('v');
        return state.copyWith(scores: scores);
      case clock:
        final run = e.get<bool>('run') ?? false;
        if (run == state.clockRunning) return state;
        return run
            ? state.copyWith(clockRunning: true, clockStartedAt: e.ts)
            : state.copyWith(clockRunning: false, clockBankedMs: state.elapsedMs(e.ts));
      case nextPeriod:
        return state.copyWith(period: state.period + 1, clockRunning: false, clockBankedMs: 0);
    }
    return state;
  }

  @override
  List<Standing> standings(CounterState state, Game game) => rankStandings(
        [for (final p in game.participants) Standing(participantId: p.id, score: state.scores[p.id] ?? 0)],
        lowWins: game.flag('lowWins'),
      );

  @override
  bool isFinished(CounterState state, Game game) {
    final target = game.intSetting('target');
    if (target == null || target <= 0) return false;
    return state.scores.values.any((s) => s >= target);
  }

  @override
  String describe(ScoreEvent e, Game game) => switch (e.type) {
        add => '${game.nameOf(e.get<String>('p') ?? '')} ${signed(e.intOf('v'))}',
        set => '${game.nameOf(e.get<String>('p') ?? '')} set to ${e.intOf('v')}',
        clock => (e.get<bool>('run') ?? false) ? 'Clock started' : 'Clock paused',
        nextPeriod => 'Next period',
        _ => e.type,
      };
}
