import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/app/app.dart';
import 'package:scoreease/app/di.dart';
import 'package:scoreease/data/cloud/access_remote.dart';
import 'package:scoreease/data/cloud/legacy_board_remote.dart';
import 'package:scoreease/data/cloud/live_board_remote.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/engine/engine.dart';

late Directory _dir;
late LocalStore _store;

Future<void> _setUp() async {
  useGoogleFonts = false;
  _dir = await Directory.systemTemp.createTemp('scoreease_test');
  Hive.init(_dir.path);
  _store = LocalStore.withBoxes(
    await Hive.openBox<String>('games'),
    await Hive.openBox<String>('events'),
    await Hive.openBox<String>('players'),
    await Hive.openBox('settings'),
  );
  final access = AccessRemote();
  await getIt.reset();
  getIt
    ..registerSingleton<LocalStore>(_store)
    ..registerSingleton<SettingsStore>(SettingsStore(_store.settingsBox))
    ..registerSingleton<AccessRemote>(access)
    ..registerSingleton<LiveBoardRemote>(LiveBoardRemote(access))
    ..registerSingleton<LegacyBoardRemote>(LegacyBoardRemote(access));
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ScoreEaseApp());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async => _setUp());
  tearDown(() async {
    await Hive.close();
    await _dir.delete(recursive: true);
  });

  testWidgets('phones get a bottom navigation bar', (tester) async {
    await _pumpAt(tester, const Size(375, 812));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Keep score of anything.'), findsOneWidget);
  });

  testWidgets('tablets get a navigation rail', (tester) async {
    await _pumpAt(tester, const Size(800, 1024));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('desktop gets an extended rail with a New game button', (tester) async {
    await _pumpAt(tester, const Size(1280, 800));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.widgetWithText(FilledButton, 'New game'), findsOneWidget);
  });

  testWidgets('saved games are listed on the home screen', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() => _store.saveGame(Game(
          id: 'g1',
          title: 'Friday rummy',
          templateId: 'rummy',
          mode: GameMode.rounds,
          participants: const [Participant(id: 'p0', name: 'Ann'), Participant(id: 'p1', name: 'Bob')],
          createdAt: now,
          updatedAt: now,
          summary: 'Ann 10 · Bob 20',
        )));
    await _pumpAt(tester, const Size(375, 812));
    expect(find.text('Friday rummy'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });
}
