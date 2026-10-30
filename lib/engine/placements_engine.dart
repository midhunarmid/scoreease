import 'engine.dart';

/// Games decided by finishing order: musical chairs (players go out one by
/// one, the last one in wins) or a race (players finish one by one).
///
/// Settings: `order` ("out" or "finish"), `placePoints` ("3,2,1"): points
/// for 1st, 2nd, 3rd... shown on the board and counted in events.
class PlacementsState {
  /// Players placed so far, in the order it happened.
  final List<String> order;

  const PlacementsState(this.order);
}

class PlacementsEngine extends ScoringEngine<PlacementsState> {
  const PlacementsEngine();

  /// Places a player: `{p: pid}`. Out (elimination) or finished, per `order`.
  static const place = 'place';

  static bool isElimination(Game game) => game.stringSetting('order') != 'finish';

  /// Points for 1st, 2nd, 3rd... Places past the end of the list get 0.
  static List<int> placePointsOf(Game game) => parsePlacePoints(game.stringSetting('placePoints'));

  /// The place each placed player got. The last player left takes the
  /// remaining place once everyone else is placed.
  static Map<String, int> places(PlacementsState state, Game game) {
    final n = game.participants.length;
    final elimination = isElimination(game);
    final out = <String, int>{
      for (final (i, pid) in state.order.indexed) pid: elimination ? n - i : i + 1,
    };
    if (state.order.length == n - 1) {
      for (final p in game.participants) {
        if (!out.containsKey(p.id)) out[p.id] = elimination ? 1 : n;
      }
    }
    return out;
  }

  /// Players not placed yet.
  static List<Participant> stillIn(PlacementsState state, Game game) =>
      game.participants.where((p) => !state.order.contains(p.id)).toList();

  @override
  PlacementsState initial(Game game) => const PlacementsState([]);

  /// Places depend on how many are playing, so the field is set at the first
  /// place.
  @override
  bool canSub(PlacementsState state, Game game) => state.order.isEmpty;

  @override
  bool canChangeSides(PlacementsState state, Game game) => state.order.isEmpty;

  @override
  PlacementsState apply(PlacementsState state, ScoreEvent e, Game game) {
    if (e.type != place) return state;
    final pid = e.get<String>('p');
    if (pid == null || game.participant(pid) == null || state.order.contains(pid)) return state;
    return PlacementsState([...state.order, pid]);
  }

  @override
  bool isFinished(PlacementsState state, Game game) => game.participants.length > 1 && state.order.length >= game.participants.length - 1;

  @override
  List<Standing> standings(PlacementsState state, Game game) {
    final placed = places(state, game);
    final points = placePointsOf(game);
    final rows = [
      for (final p in game.participants)
        Standing(
          participantId: p.id,
          score: placed[p.id] == null ? 0 : pointsForPlace(points, placed[p.id]!),
          detail: switch (placed[p.id]) {
            null => 'Still in',
            final place => isElimination(game) && place > 1 ? 'Out · ${ordinal(place)}' : ordinal(place),
          },
          rank: placed[p.id] ?? 0,
        ),
    ];
    // Placed players by place; players still in go first in elimination
    // games (they are doing best) and last in races.
    int key(Standing s) => s.rank == 0 ? (isElimination(game) ? 0 : 1 << 20) : s.rank;
    return rows..sort((a, b) => key(a).compareTo(key(b)));
  }

  /// When ended by hand, everyone still in an elimination game shares 1st.
  @override
  List<String> winners(PlacementsState state, Game game, List<Standing> standings) {
    final placed = places(state, game);
    final first = placed.entries.where((e) => e.value == 1).map((e) => e.key).toList();
    if (first.isNotEmpty) return first;
    return isElimination(game) ? stillIn(state, game).map((p) => p.id).toList() : const [];
  }

  @override
  String describe(ScoreEvent e, Game game) {
    final name = game.nameOf(e.get<String>('p') ?? '');
    return e.type == place ? (isElimination(game) ? '$name is out' : '$name finished') : e.type;
  }

  @override
  String summary(PlacementsState state, Game game, List<Standing> standings) {
    final left = stillIn(state, game).length;
    if (left > 1 || (left == 1 && !isFinished(state, game))) return '$left still in';
    return standings.where((s) => s.rank > 0).take(3).map((s) => '${ordinal(s.rank)} ${game.nameOf(s.participantId)}').join(' · ');
  }
}

/// "3,2,1" → [3, 2, 1]. Blank or invalid gives the usual 3-2-1.
List<int> parsePlacePoints(String? raw) {
  final points = (raw ?? '').split(',').map((s) => int.tryParse(s.trim())).whereType<int>().where((v) => v >= 0).toList();
  return points.isEmpty ? const [3, 2, 1] : points;
}

int pointsForPlace(List<int> points, int place) => place >= 1 && place <= points.length ? points[place - 1] : 0;

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}
