import 'models.dart';
import 'counter_engine.dart';
import 'rounds_engine.dart';
import 'sets_engine.dart';
import 'cricket_engine.dart';
import 'lineup.dart';
import 'placements_engine.dart';

export 'models.dart';

/// Event types shared by every mode.
class EventTypes {
  static const undo = 'undo';
  static const redo = 'redo';

  /// Ends the game by hand (counter and rounds games have no natural end).
  static const end = 'end';

  /// Credits team members with a scoring event:
  /// `{target: eventId, m: {m0: 1, m2: 1}}`. No `m` clears the tag. The
  /// latest tag for a target wins. Allowed after the game has ended.
  static const tag = 'tag';

  /// Changes who plays for a side. On a team `{p, o: memberIndex, n: name}`
  /// swaps them; leaving out `o` adds `n`, leaving out `n` removes member
  /// `o`. On an individual side `{p, n: name}`. Earlier points stay with
  /// whoever scored them.
  static const sub = 'sub';

  /// A new side joins: `{n: name, c: color, t: eventTeamId, m0: member...}`.
  /// Its participant id is this event's id, so it is never reused.
  static const addSide = 'addSide';

  /// A side leaves the game: `{p: pid}`.
  static const retire = 'retire';

  /// Corrects a name everywhere in the game: `{f: from, n: to}`, matched
  /// ignoring case. Allowed after the game has ended.
  static const rename = 'rename';

  /// Change no score: not undone by hand, and out of the log.
  static const silent = {tag, rename};

  /// Change who is playing. Refused once the game has ended.
  static const lineup = {sub, addSide, retire};
}

/// Member indexes from a `tag` event's `m` map (`{m0: 1, m2: 1}` → {0, 2}).
Set<int> tagMembers(ScoreEvent e) {
  final raw = e.data['m'];
  if (raw is! Map) return const {};
  return {
    for (final k in raw.keys)
      if (int.tryParse(k.toString().replaceFirst('m', '')) case final i?) i,
  };
}

/// Data for a `tag` event crediting [members] with [target].
Map<String, dynamic> tagData(String target, Iterable<int> members) => {
      'target': target,
      if (members.isNotEmpty) 'm': {for (final i in members) 'm$i': 1},
    };

/// Points a scoring event gave a participant.
typedef Credit = ({String pid, int v});

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

  /// Scoring events that count towards team members, by event id. Only
  /// events that changed the score are here.
  final Map<String, Credit> creditable;

  /// Current member tags, by scoring event id (member indexes).
  final Map<String, Set<int>> tags;

  /// The game as set up, before any lineup event. Null when it is [game].
  final Game? base;

  /// Each lineup in turn, oldest first, and the event that started it.
  final List<({String from, Game game})> eras;

  /// Log lines for lineup events, by event id, e.g. "Ann replaced by Bob".
  final Map<String, String> notes;

  /// Whether the events changed anyone's name or place in the game.
  final bool lineupChanged;

  /// Whether a player can be swapped now.
  final bool canSub;

  /// Whether sides can join or leave now.
  final bool canChangeSides;

  /// Whether teams must keep their size (badminton courts).
  final bool fixedTeams;

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
    this.creditable = const {},
    this.tags = const {},
    this.base,
    this.eras = const [],
    this.notes = const {},
    this.lineupChanged = false,
    this.canSub = false,
    this.canChangeSides = false,
    this.fixedTeams = false,
  });

  T stateAs<T>() => state as T;

  /// The game with the lineup in force when event [id] happened.
  Game gameAt(String id) {
    var out = eras.isEmpty ? game : eras.first.game;
    for (final era in eras) {
      if (era.from.compareTo(id) <= 0) out = era.game;
    }
    return out;
  }

  /// The copy kept on the device. Its participants stay as set up, because
  /// the events replay on them.
  Game toSaved(DateTime updatedAt, {String? id}) => Game(
        id: id ?? game.id,
        title: game.title,
        templateId: game.templateId,
        mode: game.mode,
        settings: game.settings,
        participants: (base ?? game).participants,
        createdAt: game.createdAt,
        updatedAt: updatedAt,
        status: finished ? GameStatus.finished : GameStatus.active,
        winners: winners,
        summary: summary,
        shareCode: game.shareCode,
        isOwner: game.isOwner,
        memberPoints: memberPointsByName,
        eventId: game.eventId,
        lineup: lineupChanged ? game.participants : const [],
      );

  /// Points each team member was involved in: participant id → member
  /// index → points. Every tagged member gets the full value.
  Map<String, Map<int, int>> get memberPoints {
    final out = <String, Map<int, int>>{};
    for (final MapEntry(key: id, value: credit) in creditable.entries) {
      final members = tags[id];
      if (members == null) continue;
      final team = game.participant(credit.pid);
      if (team == null) continue;
      final row = out.putIfAbsent(credit.pid, () => {});
      for (final i in members) {
        if (i >= 0 && i < team.members.length) row[i] = (row[i] ?? 0) + credit.v;
      }
    }
    return out;
  }

  /// [memberPoints] keyed by member name, for stats.
  Map<String, int> get memberPointsByName {
    final out = <String, int>{};
    for (final MapEntry(key: pid, value: row) in memberPoints.entries) {
      for (final MapEntry(key: i, value: v) in row.entries) {
        final name = game.participant(pid)!.members[i];
        out[name] = (out[name] ?? 0) + v;
      }
    }
    return out;
  }

  /// The log line for [e], with who scored when tagged: "Reds +1 · Ann, Bob".
  String describe(ScoreEvent e) {
    final note = notes[e.id];
    if (note != null) return note;
    final line = GameEngine.describe(gameAt(e.id), e);
    final members = tags[e.id];
    final team = creditable[e.id] == null ? null : game.participant(creditable[e.id]!.pid);
    if (members == null || team == null) return line;
    return '$line · ${(members.toList()..sort()).where((i) => i < team.members.length).map((i) => team.members[i]).join(', ')}';
  }

  /// Log events, newest first, without the tags (they show on their score)
  /// and spelling fixes.
  List<ScoreEvent> get log => effective.reversed.where((e) => !EventTypes.silent.contains(e.type)).toList();

  /// "Ann 5 · Bob 3 · Cy" for a team, best first. Members without points
  /// are listed by name only. Anyone swapped out shows only if they scored.
  String membersLine(Participant team) {
    final points = memberPoints[team.id] ?? const {};
    final onCourt = team.onCourt;
    final order = [
      for (var i = 0; i < team.members.length; i++)
        if (onCourt.contains(i) || points.containsKey(i)) i,
    ]..sort((a, b) => (points[b] ?? 0).compareTo(points[a] ?? 0));
    return order.map((i) => points.containsKey(i) ? '${team.members[i]} ${points[i]}' : team.members[i]).join(' · ');
  }

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
    final sides = game.sides.length;
    return top.length == sides && sides > 1 ? const [] : top;
  }

  String resultText(S state, Game game, List<String> winners, List<Standing> standings) {
    if (winners.isEmpty) return 'It\'s a tie';
    final names = winners.map(game.nameOf).join(' & ');
    return '$names ${winners.length > 1 ? 'win' : 'wins'}!';
  }

  /// One line for the history log.
  String describe(ScoreEvent event, Game game);

  /// The participant and points an event scores, if team members can be
  /// credited with it.
  Credit? creditable(ScoreEvent event, Game game) => null;

  /// Whether a player can be swapped now.
  bool canSub(S state, Game game) => true;

  /// Whether sides can join or leave now.
  bool canChangeSides(S state, Game game) => false;

  /// Whether teams must keep their size.
  bool fixedTeams(Game game) => false;

  /// The state after [side] joins a game in progress. [game] already has it.
  S addSide(S state, Participant side, Game game) => state;

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
        GameMode.placements => const PlacementsEngine(),
      };

  static GameSnapshot compute(Game base, List<ScoreEvent> events) {
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
        // Tagging who scored or fixing a name doesn't lose what could be redone.
        if (!EventTypes.silent.contains(e.type)) redoStack.clear();
      }
    }
    final kept = scoring.where((e) => !undone.contains(e.id)).toList();

    final engine = engineFor(base.mode);
    final fix = nameFixes(kept);
    var game = base.copyWith(
      participants: [for (final p in base.participants) renamedParticipant(p, fix)],
      lineup: const [],
    );
    var state = engine.initial(game);
    var endedByHand = false;
    var started = false;
    var eras = <({String from, Game game})>[(from: '', game: game)];
    final notes = <String, String>{};
    final refused = <String>{};
    final creditable = <String, Credit>{};
    final tags = <String, Set<int>>{};
    for (final e in kept) {
      if (e.type == EventTypes.rename) continue;
      if (e.type == EventTypes.tag) {
        final target = e.get<String>('target');
        if (target == null) continue;
        final members = tagMembers(e);
        if (members.isEmpty) {
          tags.remove(target);
        } else {
          tags[target] = members;
        }
        continue;
      }
      if (e.type == EventTypes.end) {
        endedByHand = true;
        continue;
      }
      final lineup = EventTypes.lineup.contains(e.type);
      if (endedByHand || engine.isFinished(state, game)) {
        if (lineup) refused.add(e.id);
        continue;
      }
      if (lineup) {
        final change = resolveLineup(
          e,
          game,
          started: started,
          canSub: engine.canSub(state, game),
          canChangeSides: engine.canChangeSides(state, game),
          fixedTeams: engine.fixedTeams(game),
          fix: fix,
        );
        if (change == null) {
          refused.add(e.id);
          continue;
        }
        game = game.copyWith(participants: change.participants);
        notes[e.id] = change.note;
        if (started) {
          if (change.joined case final side?) state = engine.addSide(state, side, game);
          eras.add((from: e.id, game: game));
        } else {
          // Nothing has been played, so it is as if it was set up this way.
          state = engine.initial(game);
          eras = [(from: '', game: game)];
        }
        continue;
      }
      state = engine.apply(state, e, game);
      started = true;
      final credit = engine.creditable(e, game);
      final side = credit == null ? null : game.participant(credit.pid);
      if (credit != null && credit.v != 0 && side != null && side.isTeam && !side.retired) creditable[e.id] = credit;
    }
    tags.removeWhere((id, _) => !creditable.containsKey(id));
    final effective = kept.where((e) => !refused.contains(e.id)).toList();
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
      canUndo: effective.any((e) => !EventTypes.silent.contains(e.type)),
      redoTarget: redoStack.isEmpty ? null : redoStack.last,
      creditable: creditable,
      tags: tags,
      base: base,
      eras: eras,
      notes: notes,
      lineupChanged: notes.isNotEmpty || effective.any((e) => e.type == EventTypes.rename),
      canSub: !finished && engine.canSub(state, game),
      canChangeSides: !finished && engine.canChangeSides(state, game),
      fixedTeams: engine.fixedTeams(game),
    );
  }

  static String describe(Game game, ScoreEvent event) {
    if (event.type == EventTypes.end) return 'Game ended';
    if (event.type == EventTypes.tag) return 'Tagged who scored';
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
