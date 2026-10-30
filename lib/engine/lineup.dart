import 'engine.dart';

/// Lineup events ([EventTypes.sub], [EventTypes.addSide], [EventTypes.retire])
/// resolved one at a time while a game replays, so a change of players stays
/// in the log, can be undone, and leaves earlier points where they were.
class LineupChange {
  final List<Participant> participants;

  /// The log line, e.g. "Ann replaced by Bob".
  final String note;

  /// The side that joined, if one did.
  final Participant? joined;

  const LineupChange(this.participants, this.note, {this.joined});
}

const maxNameLength = 40;

bool sameName(String a, String b) => a.toLowerCase() == b.toLowerCase();

/// A function applying the spelling fixes in [events], oldest first.
String Function(String) nameFixes(Iterable<ScoreEvent> events) {
  final fixes = [
    for (final e in events)
      if (e.type == EventTypes.rename)
        if ((e.get<String>('f'), e.get<String>('n')) case (final from?, final to?))
          if (to.trim().isNotEmpty) (from: from, to: to.trim()),
  ];
  return (name) {
    var out = name;
    for (final fix in fixes) {
      if (sameName(out, fix.from)) out = fix.to;
    }
    return out;
  };
}

Participant renamedParticipant(Participant p, String Function(String) fix) => p.copyWith(
      name: fix(p.name),
      members: p.members.map(fix).toList(),
      former: p.former.map(fix).toList(),
    );

/// What lineup event [e] does to [game], or null if it can't happen, for
/// example when two devices changed the same side at once.
///
/// Until [started], nothing has been played, so changes are made in place and
/// nobody counts as having played. After that, member lists only grow, which
/// keeps the member indexes in tags valid.
LineupChange? resolveLineup(
  ScoreEvent e,
  Game game, {
  required bool started,
  required bool canSub,
  required bool canChangeSides,
  required bool fixedTeams,
  required String Function(String) fix,
}) {
  String? name(String key) {
    final raw = e.get<String>(key)?.trim();
    return raw == null || raw.isEmpty || raw.length > maxNameLength ? null : fix(raw);
  }

  LineupChange? replacing(Participant next, String note) => LineupChange(
        [for (final p in game.participants) p.id == next.id ? next : p],
        note,
      );

  switch (e.type) {
    case EventTypes.addSide:
      final added = name('n');
      if (!canChangeSides || added == null) return null;
      if (game.sides.any((p) => sameName(p.name, added))) return null;
      final keys = e.data.keys.where((k) => RegExp(r'^m\d+$').hasMatch(k)).toList()
        ..sort((a, b) => int.parse(a.substring(1)).compareTo(int.parse(b.substring(1))));
      final side = Participant(
        id: e.id,
        name: added,
        color: e.intOf('c'),
        members: [for (final k in keys) fix(e.data[k].toString())],
        teamId: e.get<String>('t'),
      );
      return LineupChange([...game.participants, side], '$added joined', joined: side);

    case EventTypes.retire:
      final side = game.participant(e.get<String>('p') ?? '');
      if (!canChangeSides || side == null || side.retired || game.sides.length <= 1) return null;
      return started
          ? replacing(side.copyWith(retired: true), '${side.name} retired')
          : LineupChange([...game.participants]..remove(side), '${side.name} removed');

    case EventTypes.sub:
      final side = game.participant(e.get<String>('p') ?? '');
      if (!canSub || side == null || side.retired) return null;
      final incoming = name('n');
      if (!side.isTeam) {
        if (incoming == null || sameName(incoming, side.name)) return null;
        final former = started ? [...side.former.where((n) => !sameName(n, incoming)), side.name] : side.former;
        return replacing(side.copyWith(name: incoming, former: former), '${side.name} replaced by $incoming');
      }
      return _subMember(side, e.get<num>('o')?.toInt(), incoming, started: started, fixedTeams: fixedTeams, replacing: replacing);
  }
  return null;
}

LineupChange? _subMember(
  Participant team,
  int? out,
  String? incoming, {
  required bool started,
  required bool fixedTeams,
  required LineupChange? Function(Participant, String) replacing,
}) {
  if (out == null && incoming == null) return null;
  final court = [...team.onCourt];
  if (out != null && !court.contains(out)) return null;
  if (incoming != null && court.any((i) => sameName(team.members[i], incoming))) return null;
  if ((out == null || incoming == null) && fixedTeams) return null;
  if (incoming == null && court.length <= 1) return null;

  final members = [...team.members];
  final leaving = out == null ? null : members[out];
  final note = switch ((leaving, incoming)) {
    (final a?, final b?) => '$a replaced by $b',
    (final a?, null) => '$a left ${team.name}',
    (null, final b?) => '$b joined ${team.name}',
    _ => '',
  };

  if (!started) {
    if (out != null && incoming != null) {
      members[out] = incoming;
    } else if (out != null) {
      members.removeAt(out);
    } else {
      members.add(incoming!);
    }
    return replacing(team.copyWith(members: members), note);
  }

  var joining = -1;
  if (incoming != null) {
    // Coming back on: the same person keeps the same index.
    joining = members.indexWhere((m) => sameName(m, incoming));
    if (joining < 0) {
      members.add(incoming);
      joining = members.length - 1;
    }
  }
  if (out == null) {
    court.add(joining);
  } else if (incoming == null) {
    court.remove(out);
  } else {
    court[court.indexOf(out)] = joining;
  }
  return replacing(team.copyWith(members: members, court: court), note);
}
