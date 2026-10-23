import 'models.dart';
import 'counter_engine.dart';
import 'rounds_engine.dart';
import 'sets_engine.dart';
import 'cricket_engine.dart';

export 'models.dart';

/// Event types shared by every mode.
class EventTypes {
  static const undo = 'undo';
  static const redo = 'redo';

  /// Ends the game by hand (counter and rounds games have no natural end).
  static const end = 'end';
}

/// One row of the leaderboard.
class Standing {
  final String participantId;
  final num score;

  /// Secondary line shown under the score, e.g. "Sets 2" or "45/3 (5.2)".
  final String detail;
  final int rank;
  final bool out;

  const Standing({required this.participantId, required this.score, this.detail = '', this.rank = 0, this.out = false});
}

/// Everything the UI needs to draw a game at a point in time.
class GameSnapshot {
  final Game game;

  /// The mode-specific state, e.g. [CounterState].
  final Object state;
  final List<Standing> standings;
  final bool finished;
  final List<String> winners;

  /// e.g. "Ann won by 3 points" once finished.
  final String resultText;

  /// Events still in effect (undone ones removed), oldest first.
  final List<ScoreEvent> effective;
  final bool canUndo;

  /// The undone event a redo would bring back.
  final String? redoTarget;
  bool get canRedo => redoTarget != null;

  const GameSnapshot({
    required this.game,
    required this.state,
    required this.standings,
    required this.finished,
    required this.winners,
    required this.resultText,
    required this.effective,
    required this.canUndo,
    this.redoTarget,
  });

  T stateAs<T>() => state as T;

  /// Short summary for lists, e.g. "Ann 21 · Bob 18".
  String get summary => GameEngine.engineFor(game.mode).summary(state, game, standings);
}

/// A scoring mode. Engines are pure: same game + events always gives the same
/// state, on every device.
abstract class ScoringEngine<S extends Object> {
  const ScoringEngine();

  S initial(Game game);
  S apply(S state, ScoreEvent event, Game game);
  List<Standing> standings(S state, Game game);

  /// Whether the game ended on its own (target reached, innings done...).
  bool isFinished(S state, Game game) => false;

  /// Winner ids. Called when finished, or when ended by hand.
  List<String> winners(S state, Game game, List<Standing> standings) {
    if (standings.isEmpty) return const [];
    final top = standings.where((s) => s.rank == 1).map((s) => s.participantId).toList();
    return top.length == standings.length && standings.length > 1 ? const [] : top;
  }

  String resultText(S state, Game game, List<String> winners, List<Standing> standings) {
    if (winners.isEmpty) return 'It\'s a tie';
    final names = winners.map(game.nameOf).join(' & ');
    return '$names ${winners.length > 1 ? 'win' : 'wins'}!';
  }

  /// One line for the history log.
  String describe(ScoreEvent event, Game game);

  /// Short line for game lists.
  String summary(S state, Game game, List<Standing> standings) =>
      standings.take(4).map((s) => '${game.nameOf(s.participantId)} ${formatNum(s.score)}').join(' · ');
}

String formatNum(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

/// Computes the current state of a game from its event log.
class GameEngine {
  static ScoringEngine engineFor(GameMode mode) => switch (mode) {
        GameMode.counter => const CounterEngine() as ScoringEngine,
        GameMode.rounds => const RoundsEngine(),
        GameMode.sets => const SetsEngine(),
        GameMode.cricket => const CricketEngine(),
      };

  static GameSnapshot compute(Game game, List<ScoreEvent> events) {
    final sorted = [...events]..sort((a, b) => a.id.compareTo(b.id));
    final undone = <String>{};
    final redoStack = <String>[];
    final scoring = <ScoreEvent>[];
    for (final e in sorted) {
      if (e.type == EventTypes.undo) {
        final target = e.get<String>('target');
        if (target != null && undone.add(target)) redoStack.add(target);
      } else if (e.type == EventTypes.redo) {
        final target = e.get<String>('target');
        if (target != null && undone.remove(target)) redoStack.remove(target);
      } else {
        scoring.add(e);
        redoStack.clear();
      }
    }
    final effective = scoring.where((e) => !undone.contains(e.id)).toList();

    final engine = engineFor(game.mode);
    var state = engine.initial(game);
    var endedByHand = false;
    for (final e in effective) {
      if (e.type == EventTypes.end) {
        endedByHand = true;
        continue;
      }
      if (endedByHand || engine.isFinished(state, game)) continue;
      state = engine.apply(state, e, game);
    }
    final standings = engine.standings(state, game);
    final finished = endedByHand || engine.isFinished(state, game);
    final winners = finished ? engine.winners(state, game, standings) : const <String>[];
    return GameSnapshot(
      game: game,
      state: state,
      standings: standings,
      finished: finished,
      winners: winners,
      resultText: finished ? engine.resultText(state, game, winners, standings) : '',
      effective: effective,
      canUndo: effective.isNotEmpty,
      redoTarget: redoStack.isEmpty ? null : redoStack.last,
    );
  }

  static String describe(Game game, ScoreEvent event) {
    if (event.type == EventTypes.end) return 'Game ended';
    return engineFor(game.mode).describe(event, game);
  }
}

/// Ranks participants by score. Ties share a rank.
List<Standing> rankStandings(
  List<Standing> rows, {
  bool lowWins = false,
  int Function(Standing a, Standing b)? tieBreak,
}) {
  int compare(Standing a, Standing b) {
    if (a.out != b.out) return a.out ? 1 : -1;
    final c = lowWins ? a.score.compareTo(b.score) : b.score.compareTo(a.score);
    if (c != 0) return c;
    return tieBreak?.call(a, b) ?? 0;
  }

  final sorted = [...rows]..sort(compare);
  final result = <Standing>[];
  for (var i = 0; i < sorted.length; i++) {
    final s = sorted[i];
    final rank = i > 0 && compare(sorted[i - 1], s) == 0 ? result[i - 1].rank : i + 1;
    result.add(Standing(participantId: s.participantId, score: s.score, detail: s.detail, rank: rank, out: s.out));
  }
  return result;
}

String signed(int v) => v >= 0 ? '+$v' : '$v';
