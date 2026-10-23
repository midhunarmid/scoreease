import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_page.dart';
import '../features/home/home_page.dart';
import '../features/live/legacy_board_page.dart';
import '../features/live/live_page.dart';
import '../features/new_game/new_game_page.dart';
import '../features/not_found_page.dart';
import '../features/play/play_page.dart';
import '../features/play/tv_page.dart';
import '../features/players/players_page.dart';
import '../features/settings/settings_page.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  errorBuilder: (context, state) => const NotFoundPage(),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, __) => const HomePage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (_, __) => const HistoryPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/players', builder: (_, __) => const PlayersPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsPage())]),
      ],
    ),
    GoRoute(
      path: '/new',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => NewGamePage(
        templateId: state.uri.queryParameters['template'],
        rematchOf: state.uri.queryParameters['rematch'],
      ),
    ),
    GoRoute(
      path: '/game/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => PlayPage.local(gameId: state.pathParameters['id']!),
      routes: [
        GoRoute(path: 'tv', parentNavigatorKey: _rootKey, builder: (_, state) => TvPage.local(gameId: state.pathParameters['id']!)),
      ],
    ),
    GoRoute(
      path: '/live/:code',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => LivePage(code: state.pathParameters['code']!.toLowerCase()),
      routes: [
        GoRoute(
          path: 'score',
          parentNavigatorKey: _rootKey,
          builder: (_, state) => PlayPage.live(code: state.pathParameters['code']!.toLowerCase()),
        ),
        GoRoute(
          path: 'tv',
          parentNavigatorKey: _rootKey,
          builder: (_, state) => TvPage.live(code: state.pathParameters['code']!.toLowerCase()),
        ),
      ],
    ),
    // Links from ScoreEase 1.x.
    GoRoute(
      path: '/display',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => LegacyBoardPage(id: state.uri.queryParameters['id'] ?? ''),
    ),
    GoRoute(path: '/update', redirect: (_, state) => '/display?id=${state.uri.queryParameters['id'] ?? ''}'),
    GoRoute(path: '/edit', redirect: (_, state) => '/display?id=${state.uri.queryParameters['id'] ?? ''}'),
    GoRoute(path: '/home', redirect: (_, __) => '/'),
  ],
);

/// Goes back if possible, otherwise to [fallback]. Deep-linked pages have no
/// history to pop.
void goBack(BuildContext context, [String fallback = '/']) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
