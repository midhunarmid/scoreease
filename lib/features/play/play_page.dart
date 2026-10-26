import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/di.dart';
import '../../app/router.dart';
import '../../data/cloud/access_remote.dart';
import '../../data/cloud/cloud.dart';
import '../../data/local/local_store.dart';
import '../../data/local/settings_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/counter_engine.dart';
import '../../engine/cricket_engine.dart';
import '../../engine/engine.dart';
import '../../engine/event_scoring.dart';
import '../../engine/placements_engine.dart';
import '../../engine/sets_engine.dart';
import '../../engine/templates.dart';
import '../common/game_ui.dart';
import '../events/event_data.dart';
import '../share/share_sheet.dart';
import 'export.dart';
import 'play_cubit.dart';
import 'views/counter_view.dart';
import 'views/cricket_view.dart';
import 'views/placements_view.dart';
import 'views/rounds_view.dart';
import 'views/sets_view.dart';
import 'widgets/game_side_panel.dart';
import 'widgets/password_gate.dart';
import 'widgets/result_banner.dart';

/// The scoring screen, for local games and for co-scoring a live one.
class PlayPage extends StatelessWidget {
  final String? gameId;
  final String? code;

  const PlayPage.local({super.key, required String this.gameId}) : code = null;
  const PlayPage.live({super.key, required String this.code}) : gameId = null;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) {
          final cubit = PlayCubit();
          if (gameId != null) {
            cubit.openLocal(gameId!);
          } else {
            cubit.openLive(code!, AccessLevel.write);
          }
          return cubit;
        },
        child: const _PlayView(),
      );
}

class _PlayView extends StatefulWidget {
  const _PlayView();

  @override
  State<_PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends State<_PlayView> {
  final _settings = getIt<SettingsStore>();
  StreamSubscription? _finishSub;
  StreamSubscription? _errorSub;
  final _roundsKey = GlobalKey<RoundsViewState>();

  @override
  void initState() {
    super.initState();
    if (_settings.keepAwake) WakelockPlus.enable().ignore();
    final cubit = context.read<PlayCubit>();
    _finishSub = cubit.onFinished.listen((snapshot) {
      if (!mounted) return;
      showResultDialog(context, snapshot);
      final meetId = snapshot.game.eventId;
      final meet = meetId == null ? null : getIt<LocalStore>().meet(meetId);
      if (meet != null) {
        final points = scoreMeet(meet, [snapshot]).games.first.teamPoints;
        toast(context, '${meet.name}: ${points.isEmpty ? 'no points' : awardLine(meet, points)}');
      }
    });
    _errorSub = cubit.actionErrors.listen((e) {
      if (mounted) toast(context, e is CloudException ? e.message : 'Couldn\'t sync. Will retry when online.');
    });
  }

  @override
  void dispose() {
    _finishSub?.cancel();
    _errorSub?.cancel();
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayCubit, PlayState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        if (state.needsPassword != null) {
          return PasswordGate(
            level: state.needsPassword!,
            onUnlock: context.read<PlayCubit>().unlock,
            onCancel: () => goBack(context),
          );
        }
        if (snapshot == null) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => goBack(context))),
            body: state.error != null
                ? ErrorState(
                    title: state.error is CloudException ? (state.error as CloudException).title : 'Couldn\'t open game',
                    message: state.error is CloudException ? (state.error as CloudException).message : '${state.error}',
                  )
                : const LoadingState(),
          );
        }
        return _buildGame(context, state, snapshot);
      },
    );
  }

  Widget _buildGame(BuildContext context, PlayState state, GameSnapshot snapshot) {
    final cubit = context.read<PlayCubit>();
    final game = snapshot.game;
    final template = Templates.byId(game.templateId);
    final expanded = context.isExpanded;
    final meet = game.eventId == null ? null : getIt<LocalStore>().meet(game.eventId!);

    final modeView = switch (game.mode) {
      GameMode.counter => ListenableBuilder(
          listenable: getIt<SettingsStore>(),
          builder: (_, __) => CounterView(
            snapshot: snapshot,
            enabled: state.canScore && !snapshot.finished,
            faceToFace: getIt<SettingsStore>().faceToFace,
          ),
        ),
      GameMode.rounds => RoundsView(key: _roundsKey, snapshot: snapshot, enabled: state.canScore && !snapshot.finished),
      GameMode.sets => SetsView(snapshot: snapshot, enabled: state.canScore && !snapshot.finished),
      GameMode.cricket => CricketView(snapshot: snapshot, enabled: state.canScore && !snapshot.finished),
      GameMode.placements => PlacementsView(
          snapshot: snapshot,
          enabled: state.canScore && !snapshot.finished,
          teams: {for (final t in meet?.teams ?? const []) t.id: (name: t.name, color: t.color)},
        ),
    };

    final body = Column(children: [
      if (snapshot.finished) ResultBanner(snapshot: snapshot, canRematch: game.isOwner),
      Expanded(child: modeView),
    ]);

    return CallbackShortcuts(
      bindings: _shortcuts(cubit, snapshot, state.canScore),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => goBack(context, meet == null ? '/' : '/event/${meet.id}')),
            titleSpacing: 0,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Flexible(
                  child: Text(
                    '${template.emoji} ${template.name}${meet == null ? '' : ' · 🏆 ${meet.name}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
                if (state.liveCode != null) ...[const SizedBox(width: Space.sm), const LiveBadge(compact: true)],
              ]),
            ]),
            actions: [
              IconButton(tooltip: 'Undo (Ctrl+Z)', onPressed: state.canScore && snapshot.canUndo ? cubit.undo : null, icon: const Icon(Icons.undo)),
              IconButton(tooltip: 'Redo (Ctrl+Y)', onPressed: state.canScore && snapshot.canRedo ? cubit.redo : null, icon: const Icon(Icons.redo)),
              if (game.isOwner)
                IconButton(
                  tooltip: 'Share live',
                  onPressed: () => showShareSheet(context, cubit),
                  icon: Icon(state.liveCode != null ? Icons.cell_tower : Icons.ios_share),
                ),
              _Menu(state: state, snapshot: snapshot, onAddRound: () => _roundsKey.currentState?.addRound()),
            ],
          ),
          body: SafeArea(
            top: false,
            child: expanded
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: body),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 340, child: GameSidePanel(snapshot: snapshot, canEdit: state.canScore)),
                  ])
                : body,
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(PlayCubit cubit, GameSnapshot snapshot, bool canScore) {
    final map = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyT): () => _openTv(context),
      const CharacterActivator('?'): () => showShortcutsHelp(context, snapshot.game.mode),
    };
    if (!canScore) return map;
    map.addAll({
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): cubit.undo,
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): cubit.undo,
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): cubit.redo,
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): cubit.redo,
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): cubit.redo,
    });
    if (snapshot.finished) return map;
    final game = snapshot.game;
    const digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    switch (game.mode) {
      case GameMode.counter:
        final step = CounterEngine.stepsOf(game).first;
        for (var i = 0; i < game.participants.length && i < 9; i++) {
          final pid = game.participants[i].id;
          map[SingleActivator(digits[i + 1])] = () => cubit.addPoints(pid, step);
          map[SingleActivator(digits[i + 1], shift: true)] = () => cubit.addPoints(pid, -step);
        }
      case GameMode.sets:
        if (game.participants.length >= 2) {
          void point(int side) => cubit.add(SetsEngine.point, {'p': game.participants[side].id});
          map[const SingleActivator(LogicalKeyboardKey.arrowLeft)] = () => point(0);
          map[const SingleActivator(LogicalKeyboardKey.arrowRight)] = () => point(1);
          map[SingleActivator(digits[1])] = () => point(0);
          map[SingleActivator(digits[2])] = () => point(1);
        }
      case GameMode.cricket:
        for (final r in [0, 1, 2, 3, 4, 6]) {
          map[SingleActivator(digits[r])] = () => cubit.add(CricketEngine.ball, {'r': r});
        }
        map[const SingleActivator(LogicalKeyboardKey.keyW)] = () => cubit.add(CricketEngine.ball, {'r': 0, 'w': true});
      case GameMode.rounds:
        map[const SingleActivator(LogicalKeyboardKey.keyN)] = () => _roundsKey.currentState?.addRound();
      case GameMode.placements:
        for (var i = 0; i < game.participants.length && i < 9; i++) {
          final pid = game.participants[i].id;
          map[SingleActivator(digits[i + 1])] = () => cubit.add(PlacementsEngine.place, {'p': pid});
        }
    }
    return map;
  }

  void _openTv(BuildContext context) {
    final state = context.read<PlayCubit>().state;
    final game = state.game;
    if (game == null) return;
    context.push(game.isOwner ? '/game/${game.id}/tv' : '/live/${state.liveCode}/tv');
  }
}

enum _MenuAction { tv, history, faceToFace, addRound, endInnings, rename, end, csv, result, shortcuts, delete }

class _Menu extends StatelessWidget {
  final PlayState state;
  final GameSnapshot snapshot;
  final VoidCallback onAddRound;

  const _Menu({required this.state, required this.snapshot, required this.onAddRound});

  Future<void> _onSelected(BuildContext context, _MenuAction action) async {
    final cubit = context.read<PlayCubit>();
    final game = snapshot.game;
    switch (action) {
      case _MenuAction.tv:
        context.push(game.isOwner ? '/game/${game.id}/tv' : '/live/${state.liveCode}/tv');
      case _MenuAction.history:
        // Live, so changing who scored from the log shows up straight away.
        showAdaptiveSheet(
          context,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: BlocBuilder<PlayCubit, PlayState>(
              builder: (context, s) => SizedBox(height: 520, child: GameSidePanel(snapshot: s.snapshot ?? snapshot, canEdit: s.canScore)),
            ),
          ),
        );
      case _MenuAction.faceToFace:
        final settings = getIt<SettingsStore>();
        settings.faceToFace = !settings.faceToFace;
      case _MenuAction.addRound:
        onAddRound();
      case _MenuAction.endInnings:
        if (await confirm(context, title: 'End this innings?', confirmLabel: 'End innings')) cubit.add(CricketEngine.endInnings);
      case _MenuAction.rename:
        final title = await promptText(context, title: 'Rename game', initial: game.title, confirmLabel: 'Save');
        if (title != null && title.trim().isNotEmpty) await cubit.updateGame(game.copyWith(title: title.trim()));
      case _MenuAction.end:
        if (await confirm(context, title: 'End the game now?', message: 'Current standings decide the winner. You can undo this.', confirmLabel: 'End game')) {
          cubit.endGame();
        }
      case _MenuAction.csv:
        await shareCsv(context, snapshot);
      case _MenuAction.result:
        showResultDialog(context, snapshot);
      case _MenuAction.shortcuts:
        showShortcutsHelp(context, game.mode);
      case _MenuAction.delete:
        if (await confirm(context, title: 'Delete this game?', message: 'This can\'t be undone.', confirmLabel: 'Delete', destructive: true)) {
          if (state.liveCode != null) await cubit.stopSharing().catchError((_) {});
          await getIt<LocalStore>().deleteGame(game.id);
          if (context.mounted) context.go('/');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final canScore = state.canScore && !snapshot.finished;
    PopupMenuItem<_MenuAction> item(_MenuAction a, IconData icon, String label) =>
        PopupMenuItem(value: a, child: ListTile(leading: Icon(icon), title: Text(label), contentPadding: EdgeInsets.zero, dense: true));
    return PopupMenuButton<_MenuAction>(
      tooltip: 'More',
      onSelected: (a) => _onSelected(context, a),
      itemBuilder: (context) => [
        item(_MenuAction.tv, Icons.tv, 'TV mode'),
        if (!context.isExpanded) item(_MenuAction.history, Icons.history, 'History & standings'),
        if (game.mode == GameMode.counter && game.participants.length == 2)
          item(_MenuAction.faceToFace, Icons.screen_rotation_alt, getIt<SettingsStore>().faceToFace ? 'Side by side' : 'Face to face'),
        if (game.mode == GameMode.rounds && canScore) item(_MenuAction.addRound, Icons.playlist_add, 'Add round'),
        if (game.mode == GameMode.cricket && canScore) item(_MenuAction.endInnings, Icons.sports_cricket, 'End innings'),
        if (game.isOwner) item(_MenuAction.rename, Icons.edit, 'Rename'),
        if (canScore && (game.mode == GameMode.counter || game.mode == GameMode.rounds || game.mode == GameMode.placements)) item(_MenuAction.end, Icons.flag, 'End game'),
        if (snapshot.finished) item(_MenuAction.result, Icons.emoji_events, 'Result card'),
        item(_MenuAction.csv, Icons.table_view, 'Export CSV'),
        item(_MenuAction.shortcuts, Icons.keyboard, 'Keyboard shortcuts'),
        if (game.isOwner) item(_MenuAction.delete, Icons.delete_outline, 'Delete'),
      ],
    );
  }
}

void showShortcutsHelp(BuildContext context, GameMode mode) {
  final rows = <(String, String)>[
    ('Ctrl+Z', 'Undo'),
    ('Ctrl+Y', 'Redo'),
    ('T', 'TV mode'),
    ...switch (mode) {
      GameMode.counter => [('1–9', 'Add to player 1–9'), ('Shift+1–9', 'Subtract')],
      GameMode.rounds => [('N', 'Add round')],
      GameMode.sets => [('← or 1', 'Point to left side'), ('→ or 2', 'Point to right side')],
      GameMode.cricket => [('0–4, 6', 'Runs off the ball'), ('W', 'Wicket')],
      GameMode.placements => [('1–9', 'Player 1–9 is out (or finishes)')],
    },
  ];
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (key, action) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
                  decoration: BoxDecoration(color: context.colors.surfaceContainerHighest, borderRadius: Radii.smAll),
                  child: Text(key, style: context.text.labelLarge?.copyWith(fontFamily: 'monospace')),
                ),
                const SizedBox(width: Space.md),
                Text(action),
              ]),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}
