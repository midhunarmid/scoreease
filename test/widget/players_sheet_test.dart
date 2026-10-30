import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/app/di.dart';
import 'package:scoreease/data/cloud/access_remote.dart';
import 'package:scoreease/data/cloud/live_board_remote.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/features/play/play_cubit.dart';
import 'package:scoreease/features/play/widgets/players_sheet.dart';

import 'memory_store.dart';

void main() {
  late Directory dir;
  late MemoryStore store;
  late PlayCubit cubit;

  setUp(() async {
    useGoogleFonts = false;
    dir = await Directory.systemTemp.createTemp('scoreease_players');
    store = await MemoryStore.open(dir);
    await getIt.reset();
    final settings = SettingsStore(store.settingsBox)..haptics = false;
    getIt
      ..registerSingleton<LocalStore>(store)
      ..registerSingleton<SettingsStore>(settings);
    final access = AccessRemote();
    cubit = PlayCubit(store: store, access: access, remote: LiveBoardRemote(access), settings: settings);
  });

  tearDown(() async {
    await cubit.close();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, GameMode mode, List<Participant> participants, {String template = 'counter', Map<String, dynamic> settings = const {}}) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final now = DateTime(2026);
      await store.saveGame(Game(id: 'g', title: 'Test', templateId: template, mode: mode, settings: settings, participants: participants, createdAt: now, updatedAt: now));
      await cubit.openLocal('g');
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: BlocProvider.value(value: cubit, child: const PlayersSheet())),
    ));
    await tester.pump();
  }

  const reds = Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']);
  const blues = Participant(id: 'p1', name: 'Blues', members: ['Cy', 'Dee']);
  const ann = Participant(id: 'p0', name: 'Ann');
  const bob = Participant(id: 'p1', name: 'Bob');

  Finder tip(String tooltip) => find.byTooltip(tooltip);

  testWidgets('a team game offers swaps, members, retiring and adding a team', (tester) async {
    await open(tester, GameMode.counter, const [reds, blues]);
    expect(tip('Swap'), findsNWidgets(4));
    expect(tip('Remove'), findsNWidgets(4));
    expect(tip('Retire'), findsNWidgets(2));
    expect(find.text('Add team'), findsOneWidget);
    expect(find.text('Add to Reds'), findsOneWidget);
    expect(find.textContaining('Swapping keeps the score'), findsOneWidget);
  });

  testWidgets('swapping someone suggests names and shows them on the side', (tester) async {
    await open(tester, GameMode.counter, const [reds, blues]);
    await tester.runAsync(() async {
      await cubit.addPoints('p0', 1);
      cubit.flushBurst();
    });
    await tester.pump();

    await tester.tap(tip('Swap').first);
    await tester.pumpAndSettle();
    expect(find.text('Swap out Ann'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('bob is already playing here'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Eli');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Eli'), findsOneWidget);
    expect(find.text('Swapped out'), findsOneWidget);
    expect(cubit.state.game!.participant('p0')!.onCourt, [2, 1]);
  });

  testWidgets('individual games swap and retire, and retired sides stay listed', (tester) async {
    await open(tester, GameMode.rounds, const [ann, bob, Participant(id: 'p2', name: 'Cy')]);
    await tester.runAsync(() => cubit.add('round', {'s': {'p0': 1, 'p1': 2, 'p2': 3}}));
    await tester.pump();
    expect(tip('Swap'), findsNWidgets(3));
    expect(find.text('Add player'), findsOneWidget);

    await tester.tap(tip('Retire').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retire').last);
    await tester.pumpAndSettle();
    expect(find.text('Retired'), findsOneWidget);
    expect(tip('Swap'), findsNWidgets(2));
    expect(cubit.state.game!.sides.map((p) => p.id), ['p1', 'p2']);
  });

  testWidgets('two-sided games swap but never add or retire', (tester) async {
    await open(tester, GameMode.sets, const [ann, bob]);
    expect(tip('Swap'), findsNWidgets(2));
    expect(tip('Retire'), findsNothing);
    expect(find.text('Add player'), findsNothing);
  });

  testWidgets('badminton teams swap but keep their size', (tester) async {
    await open(tester, GameMode.sets, const [reds, blues], template: 'badminton');
    expect(tip('Swap'), findsNWidgets(4));
    expect(tip('Remove'), findsNothing);
    expect(find.text('Add to Reds'), findsNothing);
  });

  testWidgets('placements lock once places start', (tester) async {
    await open(tester, GameMode.placements, const [ann, bob, Participant(id: 'p2', name: 'Cy')]);
    expect(tip('Swap'), findsNWidgets(3));
    await tester.runAsync(() => cubit.add('place', {'p': 'p0'}));
    await tester.pump();
    expect(tip('Swap'), findsNothing);
    expect(find.text('Add player'), findsNothing);
    expect(tip('Fix spelling'), findsNWidgets(3));
    expect(find.textContaining('Places have started'), findsOneWidget);
  });

  testWidgets('after the game only spelling can be fixed, and it updates the names', (tester) async {
    await open(tester, GameMode.counter, const [reds, blues], settings: const {'target': 1});
    await tester.runAsync(() async {
      await cubit.addPoints('p0', 1);
      cubit.flushBurst();
    });
    await tester.pump();
    expect(tip('Swap'), findsNothing);
    expect(tip('Retire'), findsNothing);
    expect(find.textContaining('The game has ended'), findsOneWidget);

    await tester.tap(tip('Fix spelling').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Ann'), findsNothing);
  });
}
