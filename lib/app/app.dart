import 'package:flutter/material.dart';

import '../data/local/settings_store.dart';
import '../design/theme.dart';
import 'di.dart';
import 'router.dart';

class ScoreEaseApp extends StatelessWidget {
  const ScoreEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = getIt<SettingsStore>();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp.router(
        title: 'ScoreEase',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
      ),
    );
  }
}
