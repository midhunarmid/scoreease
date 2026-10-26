import 'engine.dart';

/// Free-form +/- scoring with an optional target and match clock.
///
/// Settings: `lowWins` (bool), `target` (int), `winBy` (int, with a target),
/// `startAt` (int, counts down to 0 instead), `steps` ("1,2,3"),
/// `periods` (int), `periodMinutes` (int).
class CounterState {
  /// Points so far, or points left in a countdown game.
  final Map<String, int> scores;

  /// [scores] at the end of each finished period, oldest first.
  final List<Map<String, int>> periodScores;

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
    this.periodScores = const [],
  });

  int elapsedMs(int now) => clockBankedMs + (clockRunning && now > clockStartedAt ? now - clockStartedAt : 0);

  CounterState copyWith({
    Map<String, int>? scores,
    bool? clockRunning,
    int? clockStartedAt,
    int? clockBankedMs,
    int? period,
    List<Map<String, int>>? periodScores,
  }) =>
      CounterState(
        scores: scores ?? this.scores,
        clockRunning: clockRunning ?? this.clockRunning,
        clockStartedAt: clockStartedAt ?? this.clockStartedAt,
        clockBankedMs: clockBankedMs ?? this.clockBankedMs,
        period: period ?? this.period,
        periodScores: periodScores ?? this.periodScores,
      );

  /// Points scored in each period, the current one included.
  List<Map<String, int>> periodPoints(Game game) {
    final countdown = CounterEngine.isCountdown(game);
    final start = CounterEngine.startOf(game);
    final marks = [...periodScores, scores];
    return [
      for (var i = 0; i < marks.length; i++)
        {
          for (final p in game.participants)
            p.id: () {
              final before = i == 0 ? start : (marks[i - 1][p.id] ?? start);
              final now = marks[i][p.id] ?? start;
              return countdown ? before - now : now - before;
            }(),
        },
    ];
  }
}

class CounterEngine extends ScoringEngine<CounterState> {
  const CounterEngine();

  static const add = 'add';
  static const set = 'set';
  static const clock = 'clock';
  static const nextPeriod = 'period';

  static int startOf(Game game) => game.intSetting('startAt') ?? 0;
  static bool isCountdown(Game game) => startOf(game) > 0;

  /// Lowest score wins: set by hand, or a countdown to 0.
  static bool lowWins(Game game) => isCountdown(game) || game.flag('lowWins');

  /// The win-by margin when racing to a target. 1 means any lead.
  static int winByOf(Game game) => (game.intSetting('winBy') ?? 1).clamp(1, 99);

  /// Participants one step away from winning.
  static Set<String> onGamePoint(CounterState state, Game game) {
    final steps = stepsOf(game);
    if (isCountdown(game)) {
      return {
        for (final MapEntry(key: id, value: left) in state.scores.entries)
          if (left > 0 && steps.any((s) => s >= left)) id,
      };
    }
    final target = game.intSetting('target');
    if (target == null || target <= 0 || game.flag('lowWins')) return const {};
    return {
      for (final MapEntry(key: id, value: score) in state.scores.entries)
        if (steps.any((s) => _wins(score + s, _bestOther(state, id), target, winByOf(game)))) id,
    };
  }

  /// The best score among everyone but [id]; null when playing alone.
  static int? _bestOther(CounterState state, String id) =>
      state.scores.entries.where((e) => e.key != id).fold<int?>(null, (m, e) => m == null || e.value > m ? e.value : m);

  static bool _wins(int score, int? other, int target, int winBy) => score >= target && (other == null || score - other >= winBy);

  static List<int> stepsOf(Game game) {
    final raw = game.stringSetting('steps') ?? '1';
    final steps = raw.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().where((s) => s > 0).toList();
    return steps.isEmpty ? const [1] : steps;
  }

  @override
  CounterState initial(Game game) => CounterState(scores: {for (final p in game.participants) p.id: startOf(game)});

  @override
  CounterState apply(CounterState state, ScoreEvent e, Game game) {
    switch (e.type) {
      case add:
      case set:
        final pid = e.get<String>('p');
        if (pid == null || !state.scores.containsKey(pid)) return state;
        final scores = Map<String, int>.from(state.scores);
        final v = e.intOf('v');
        scores[pid] = e.type == set ? v : scores[pid]! + (isCountdown(game) ? -v : v);
        return state.copyWith(scores: scores);
      case clock:
        final run = e.get<bool>('run') ?? false;
        if (run == state.clockRunning) return state;
        return run ? state.copyWith(clockRunning: true, clockStartedAt: e.ts) : state.copyWith(clockRunning: false, clockBankedMs: state.elapsedMs(e.ts));
      case nextPeriod:
        return state.copyWith(
          period: state.period + 1,
          clockRunning: false,
          clockBankedMs: 0,
          periodScores: [...state.periodScores, state.scores],
        );
    }
    return state;
  }

  @override
  List<Standing> standings(CounterState state, Game game) => rankStandings(
        [for (final p in game.participants) Standing(participantId: p.id, score: state.scores[p.id] ?? 0)],
        lowWins: lowWins(game),
      );

  @override
  bool isFinished(CounterState state, Game game) {
    if (isCountdown(game)) return state.scores.values.any((s) => s <= 0);
    final target = game.intSetting('target');
    if (target == null || target <= 0) return false;
    if (game.flag('lowWins')) return state.scores.values.any((s) => s >= target);
    return state.scores.entries.any((e) => _wins(e.value, _bestOther(state, e.key), target, winByOf(game)));
  }

  @override
  Credit? creditable(ScoreEvent event, Game game) {
    final pid = event.get<String>('p');
    return event.type == add && pid != null ? (pid: pid, v: event.intOf('v')) : null;
  }

  @override
  String describe(ScoreEvent e, Game game) => switch (e.type) {
        add => '${game.nameOf(e.get<String>('p') ?? '')} ${signed(isCountdown(game) ? -e.intOf('v') : e.intOf('v'))}',
        set => '${game.nameOf(e.get<String>('p') ?? '')} set to ${e.intOf('v')}',
        clock => (e.get<bool>('run') ?? false) ? 'Clock started' : 'Clock paused',
        nextPeriod => 'Next period',
        _ => e.type,
      };
}
