import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../app/router.dart';
import '../../data/cloud/access_remote.dart';
import '../../data/cloud/cloud.dart';
import '../../data/cloud/legacy_board_remote.dart';
import '../../data/local/local_store.dart';
import '../../data/local/settings_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../common/game_ui.dart';
import '../play/widgets/password_gate.dart';

/// Opens a board made with ScoreEase 1.x, read-only, with an option to copy
/// it into this device as a new game.
class LegacyBoardPage extends StatefulWidget {
  final String id;
  const LegacyBoardPage({super.key, required this.id});

  @override
  State<LegacyBoardPage> createState() => _LegacyBoardPageState();
}

class _LegacyBoardPageState extends State<LegacyBoardPage> {
  final _remote = getIt<LegacyBoardRemote>();
  final _access = getIt<AccessRemote>();
  StreamSubscription<LegacyBoard>? _sub;
  LegacyBoard? _board;
  Object? _error;
  bool _needsPassword = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _needsPassword = false;
    });
    try {
      if (widget.id.isEmpty) throw CloudException.notFound;
      final meta = await _access.getMeta(widget.id);
      if (meta == null) throw CloudException.notFound;
      if (!await _access.hasAccess(widget.id, AccessLevel.read, known: meta)) {
        setState(() => _needsPassword = true);
        return;
      }
      await _sub?.cancel();
      _sub = _remote.watch(widget.id).listen(
            (b) => setState(() => _board = b),
            onError: (Object e) => setState(() => _error = e),
          );
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<bool> _unlock(String password) async {
    final ok = await _access.unlock(widget.id, AccessLevel.read, password);
    if (ok) {
      final settings = getIt<SettingsStore>();
      settings.unlockedBoards = {...settings.unlockedBoards, widget.id}.toList();
      await _open();
    }
    return ok;
  }

  Future<void> _import() async {
    final (game, events) = _board!.toLocalGame();
    final store = getIt<LocalStore>();
    await store.saveGame(game);
    await store.saveEvents(game.id, events);
    await store.rememberPlayers(game.participants);
    if (mounted) context.go('/game/${game.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_needsPassword) return PasswordGate(level: AccessLevel.read, onUnlock: _unlock, onCancel: () => goBack(context));
    final board = _board;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => goBack(context)), title: Text(board?.title ?? 'Scoreboard')),
      body: board == null
          ? (_error != null
              ? ErrorState(
                  title: _error is CloudException ? (_error as CloudException).title : 'Couldn\'t open',
                  message: _error is CloudException ? (_error as CloudException).message : '$_error',
                  onRetry: _open,
                )
              : const LoadingState())
          : ListView(
              padding: EdgeInsets.all(context.gutter),
              children: [
                MaxWidth(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Card(
                      color: context.colors.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Made with an older ScoreEase', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: Space.xs),
                          const Text('This board is view-only now. Copy it to your games to keep scoring with the new features.'),
                          const SizedBox(height: Space.md),
                          FilledButton.icon(onPressed: _import, icon: const Icon(Icons.download), label: const Text('Copy to my games')),
                        ]),
                      ),
                    ),
                    if (board.description.isNotEmpty) ...[
                      const SizedBox(height: Space.lg),
                      Text(board.description, style: context.text.bodyLarge),
                    ],
                    const SizedBox(height: Space.lg),
                    ..._rows(context, board),
                  ]),
                ),
              ],
            ),
    );
  }

  List<Widget> _rows(BuildContext context, LegacyBoard board) {
    final sorted = board.players.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    Widget row(String name, int score, int rank, int color, [String? sub]) => Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Card(
            child: ListTile(
              leading: RankBadge(rank: rank),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: sub == null ? null : Text(sub),
              trailing: Text('$score', style: scoreStyle(context, 28, color: playerColor(color))),
            ),
          ),
        );

    if (board.teams.isEmpty) {
      return [for (var i = 0; i < sorted.length; i++) row(sorted[i].key, sorted[i].value, i + 1, i)];
    }
    final teams = board.teams.entries.map((t) => (t.key, t.value, t.value.fold<int>(0, (s, m) => s + (board.players[m] ?? 0)))).toList()
      ..sort((a, b) => b.$3.compareTo(a.$3));
    return [
      for (var i = 0; i < teams.length; i++)
        row(teams[i].$1, teams[i].$3, i + 1, i, teams[i].$2.map((m) => '$m ${board.players[m] ?? 0}').join(' · ')),
    ];
  }
}
