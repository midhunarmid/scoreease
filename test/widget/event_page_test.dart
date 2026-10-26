import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/app/di.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/meet.dart';
import 'package:scoreease/features/events/event_page.dart';

import 'memory_store.dart';

void main() {
  late Directory dir;
  late MemoryStore store;

  setUp(() async {
    useGoogleFonts = false;
    dir = await Directory.systemTemp.createTemp('scoreease_event');
    store = await MemoryStore.open(dir);
    await getIt.reset();
    getIt
      ..registerSingleton<LocalStore>(store)
      ..registerSingleton<SettingsStore>(SettingsStore(store.settingsBox));
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('shows team totals and top performers, and follows an undo', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime(2026);
    await store.saveMeet(Meet(
      id: 'm',
      name: 'Games day',
      teams: const [
        MeetTeam(id: 't0', name: 'Reds', color: 1, members: ['Ann', 'Bob']),
        MeetTeam(id: 't1', name: 'Blues', members: ['Dee', 'Eve']),
      ],
      createdAt: now,
      updatedAt: now,
    ));
    await store.saveGame(Game(
      id: 'g',
      title: 'Musical chairs',
      templateId: 'musicalchairs',
      mode: GameMode.placements,
      settings: const {'order': 'out'},
      participants: const [
        Participant(id: 'p0', name: 'Ann', teamId: 't0'),
        Participant(id: 'p1', name: 'Bob', teamId: 't0'),
        Participant(id: 'p2', name: 'Dee', teamId: 't1'),
        Participant(id: 'p3', name: 'Eve', teamId: 't1'),
      ],
      createdAt: now,
      updatedAt: now,
      eventId: 'm',
    ));
    const out = [
      ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p1'}, ts: 1),
      ScoreEvent(id: 'e2', type: 'place', data: {'p': 'p2'}, ts: 2),
      ScoreEvent(id: 'e3', type: 'place', data: {'p': 'p3'}, ts: 3),
    ];
    await store.saveEvents('g', out);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const EventPage(id: 'm')));
    await tester.pump();

    // Ann 1st 3, Eve 2nd 2, Dee 3rd 1, Bob 4th 0.
    expect(find.text('Reds +3 · Blues +3'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Top performers'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);

    await store.saveEvents('g', [...out, const ScoreEvent(id: 'e4', type: 'undo', data: {'target': 'e3'}, ts: 4)]);
    await store.saveGame(store.game('g')!);
    await tester.pump();
    expect(find.text('In progress · 2 still in'), findsOneWidget, reason: 'the undone game no longer counts');
    expect(find.text('No points yet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
