import 'engine.dart';

/// Round-by-round scoring for card games and golf.
///
/// Settings: `lowWins` (bool), `target` (int, game ends when a total reaches
/// it), `eliminateAt` (int, a player is out when their total reaches it; last
/// one standing wins), `maxRounds` (int).
class RoundsState {
  /// One map per round: participant id -> points that round.
  final List<Map<String, int>> rounds;

  /// Moves the dealer along, so a player joining doesn't change whose deal
  /// is next.
  final int dealerShift;

  const RoundsState(this.rounds, {this.dealerShift = 0});

  int totalOf(String pid, [int? upToRound]) {
    var total = 0;
    final end = upToRound ?? rounds.length;
    for (var i = 0; i < end && i < rounds.length; i++) {
      total += rounds[i][pid] ?? 0;
    }
    return total;
  }
}

class RoundsEngine extends ScoringEngine<RoundsState> {
  const RoundsEngine();

  /// Adds a round: `{s: {pid: points}}`.
  static const round = 'round';

  /// Replaces round `i`: `{i: index, s: {pid: points}}`.
  static const editRound = 'editRound';

  @override
  RoundsState initial(Game game) => const RoundsState([]);

  static Map<String, int> _scores(ScoreEvent e) {
    final raw = e.data['s'];
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
  }

  @override
  RoundsState apply(RoundsState state, ScoreEvent e, Game game) {
    switch (e.type) {
      case round:
        return RoundsState([...state.rounds, _scores(e)], dealerShift: state.dealerShift);
      case editRound:
        final i = e.intOf('i', -1);
        if (i < 0 || i >= state.rounds.length) return state;
        final rounds = [...state.rounds];
        rounds[i] = _scores(e);
        return RoundsState(rounds, dealerShift: state.dealerShift);
    }
    return state;
  }

  @override
  bool canChangeSides(RoundsState state, Game game) => true;

  @override
  RoundsState addSide(RoundsState state, Participant side, Game game) {
    final seats = game.participants.length - 1;
    if (seats < 1) return state;
    final next = (state.rounds.length + state.dealerShift) % seats;
    return RoundsState(state.rounds, dealerShift: (next - state.rounds.length) % game.participants.length);
  }

  static bool isOut(RoundsState state, Game game, String pid) {
    if (game.participant(pid)?.retired ?? false) return true;
    final limit = game.intSetting('eliminateAt');
    return limit != null && limit > 0 && state.totalOf(pid) >= limit;
  }

  /// Players still in the game, in seating order.
  static List<Participant> active(RoundsState state, Game game) =>
      game.participants.where((p) => !isOut(state, game, p.id)).toList();

  /// Who deals the next round: rotates through the players still in.
  static String? dealer(RoundsState state, Game game) {
    final players = game.participants;
    if (players.isEmpty) return null;
    for (var step = 0; step < players.length; step++) {
      final p = players[(state.rounds.length + state.dealerShift + step) % players.length];
      if (!isOut(state, game, p.id)) return p.id;
    }
    return null;
  }

  @override
  List<Standing> standings(RoundsState state, Game game) => rankStandings(
        [
          for (final p in game.participants)
            Standing(
              participantId: p.id,
              score: state.totalOf(p.id),
              out: isOut(state, game, p.id),
              detail: p.retired ? 'Retired' : (isOut(state, game, p.id) ? 'Out' : ''),
            ),
        ],
        lowWins: game.flag('lowWins'),
      );

  @override
  bool isFinished(RoundsState state, Game game) {
    if (state.rounds.isEmpty) return false;
    final maxRounds = game.intSetting('maxRounds');
    if (maxRounds != null && maxRounds > 0 && state.rounds.length >= maxRounds) return true;
    final target = game.intSetting('target');
    if (target != null && target > 0 && game.sides.any((p) => state.totalOf(p.id) >= target)) return true;
    final eliminate = game.intSetting('eliminateAt');
    if (eliminate != null && eliminate > 0 && game.participants.length > 1) {
      return active(state, game).length <= 1;
    }
    return false;
  }

  @override
  String resultText(RoundsState state, Game game, List<String> winners, List<Standing> standings) {
    final base = super.resultText(state, game, winners, standings);
    return '$base · ${state.rounds.length} round${state.rounds.length == 1 ? '' : 's'}';
  }

  @override
  String describe(ScoreEvent e, Game game) {
    final scores = _scores(e);
    final parts = scores.entries.map((s) => '${game.nameOf(s.key)} ${s.value}').join(', ');
    return e.type == editRound ? 'Round ${e.intOf('i') + 1} edited: $parts' : 'Round: $parts';
  }
}
