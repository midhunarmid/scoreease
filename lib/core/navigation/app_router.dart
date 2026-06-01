import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/widgets/dummy_screen.dart';
import 'package:scoreease/features/landing/presentation/pages/landing_screen.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/score_board_setup_screen.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_score_display_screen.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_update_screen.dart';
import 'package:scoreease/features/settings/presentation/pages/settings_screen.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  errorBuilder: (context, state) => const DummyScreen(text: "Error Screen"),
  redirect: (BuildContext context, GoRouterState state) {
    if (![
      "/${LandingScreen.routeName}",
      "/${ScoreboardSetupScreen.routeName}",
      "/${ScoreboardScoreUpdateScreen.routeName}",
      "/${ScoreboardScoreDisplayScreen.routeName}",
      "/${SettingsScreen.routeName}",
      "/signin",
      "/forgotPassword",
      "/signup",
    ].contains(state.fullPath)) {
      // if any routes which needs auth, check for auth
      bool auth = FirebaseAuth.instance.currentUser != null;
      if (!auth) {
        // if not authenticated, show signin screen
        return "/${LandingScreen.routeName}";
      } else {
        // if authenticated, proceed
        return null;
      }
    } else {
      // for any screens which not need auth, proceed
      return null;
    }
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const LandingScreen();
      },
      routes: <RouteBase>[
        GoRoute(
          path: LandingScreen.routeName,
          pageBuilder: (context, state) => buildPageWithDefaultTransition<void>(
            context: context,
            state: state,
            child: const LandingScreen(),
          ),
        ),
        GoRoute(
          path: ScoreboardSetupScreen.routeName,
          pageBuilder: (context, state) => buildPageWithDefaultTransition<void>(
            context: context,
            state: state,
            child: const ScoreboardSetupScreen(),
          ),
        ),
        GoRoute(
          path: ScoreboardScoreUpdateScreen.routeName,
          pageBuilder: (context, state) => buildPageWithDefaultTransition<void>(
            context: context,
            state: state,
            child: ScoreboardScoreUpdateScreen(state.uri.queryParameters['id'] ?? "", state.extra as ScoreboardEntity?),
          ),
        ),
        GoRoute(
          path: ScoreboardScoreDisplayScreen.routeName,
          pageBuilder: (context, state) => buildPageWithDefaultTransition<void>(
            context: context,
            state: state,
            child: ScoreboardScoreDisplayScreen(state.uri.queryParameters['id'] ?? ""),
          ),
        ),
        GoRoute(
          path: SettingsScreen.routeName,
          pageBuilder: (context, state) => buildPageWithDefaultTransition<void>(
            context: context,
            state: state,
            child: const SettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'dummy',
          pageBuilder: (context, state) => buildPageWithDefaultTransition<void>(
            context: context,
            state: state,
            child: const DummyScreen(text: "Forgot Password Screen"),
          ),
        ),
      ],
    ),
  ],
);
