import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/widgets.dart';
import '../../engine/cricket_engine.dart';
import '../../engine/engine.dart';
import '../../engine/event_scoring.dart';
import '../../engine/rounds_engine.dart';
import '../../engine/sets_engine.dart';

String _safeName(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '').toLowerCase();

String _csvCell(Object? v) {
  final s = '${v ?? ''}';
  return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _csv(List<List<Object?>> rows) => rows.map((r) => r.map(_csvCell).join(',')).join('\n');

/// A spreadsheet-friendly copy of a game.
String gameCsv(GameSnapshot snapshot) {
  final game = snapshot.game;
  final names = game.participants.map((p) => p.name).toList();
  final rows = <List<Object?>>[];
  switch (game.mode) {
    case GameMode.rounds:
      final state = snapshot.stateAs<RoundsState>();
      rows.add(['Round', ...names]);
      for (var i = 0; i < state.rounds.length; i++) {
        rows.add([i + 1, for (final p in game.participants) state.rounds[i][p.id] ?? '']);
      }
      rows.add(['Total', for (final p in game.participants) state.totalOf(p.id)]);
    case GameMode.sets:
      final state = snapshot.stateAs<SetsState>();
      rows.add(['Set', ...names.take(2)]);
      for (var i = 0; i < state.sets.length; i++) {
        rows.add([i + 1, state.sets[i][0], state.sets[i][1]]);
      }
      if (!snapshot.finished) rows.add(['Current', state.current[0], state.current[1]]);
    case GameMode.cricket:
      final state = snapshot.stateAs<CricketState>();
      rows.add(['Team', 'Runs', 'Wickets', 'Overs', 'Extras', 'Balls']);
      for (final inn in state.innings) {
        rows.add([game.participants[inn.side].name, inn.runs, inn.wickets, inn.overs, inn.extras, inn.deliveries.join(' ')]);
      }
    case GameMode.placements:
      rows.add(['Place', 'Name', 'Points']);
      for (final s in snapshot.standings) {
        rows.add([s.rank == 0 ? 'Still in' : s.rank, game.nameOf(s.participantId), s.score]);
      }
    case GameMode.counter:
      rows.add(['Rank', 'Name', 'Score']);
      for (final s in snapshot.standings) {
        rows.add([s.rank, game.nameOf(s.participantId), s.score]);
      }
  }
  final memberPoints = snapshot.memberPoints;
  if (memberPoints.isNotEmpty) {
    rows.addAll([[], ['Team', 'Member', 'Points involved']]);
    for (final p in game.participants) {
      final points = memberPoints[p.id];
      if (points == null) continue;
      for (var i = 0; i < p.members.length; i++) {
        rows.add([p.name, p.members[i], points[i] ?? 0]);
      }
    }
  }
  if (snapshot.finished) rows.addAll([[], ['Result', snapshot.resultText]]);
  return _csv(rows);
}

/// A spreadsheet-friendly copy of an event: teams, games and people.
String meetCsv(MeetStandings standings) {
  final meet = standings.meet;
  final rows = <List<Object?>>[
    [meet.name],
    [],
    ['Team', 'Points', 'Players'],
    for (final t in standings.rankedTeams) [t.name, standings.teamTotals[t.id] ?? 0, t.members.join('; ')],
    [],
    ['Game', 'Status', for (final t in meet.teams) t.name],
    for (final g in standings.games) [g.game.title, g.counted ? 'Finished' : 'In progress', for (final t in meet.teams) g.teamPoints[t.id] ?? 0],
    [],
    ['Name', 'Team', 'Points', 'Played', 'Wins', 'Scored'],
    for (final p in standings.people) [p.name, meet.team(p.teamId)?.name ?? '', p.points, p.played, p.wins, p.scored],
  ];
  if (standings.resultText != null) rows.addAll([[], ['Result', standings.resultText]]);
  return _csv(rows);
}

Future<void> shareFile(BuildContext context, Uint8List bytes, String name, String mime, {String? text}) async {
  try {
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: name, mimeType: mime)], fileNameOverrides: [name], text: text));
  } catch (e) {
    if (context.mounted) toast(context, 'Couldn\'t share the file');
  }
}

Future<void> shareCsv(BuildContext context, GameSnapshot snapshot) =>
    shareFile(context, Uint8List.fromList(utf8.encode(gameCsv(snapshot))), '${_safeName(snapshot.game.title)}.csv', 'text/csv');
