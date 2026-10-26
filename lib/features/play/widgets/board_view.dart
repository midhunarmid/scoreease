import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/counter_engine.dart';
import '../../../engine/engine.dart';
import '../../../engine/sets_engine.dart';
import '../../common/game_ui.dart';
import '../views/counter_view.dart';
import '../views/cricket_view.dart';
import 'score_change.dart';

/// Read-only scoreboard for viewers and TV mode. [tv] uses huge type that
/// scales with the screen.
class BoardView extends StatelessWidget {
  final GameSnapshot snapshot;
  final bool tv;

  const BoardView({super.key, required this.snapshot, this.tv = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final scale = tv ? (c.maxWidth / 900).clamp(1.0, 2.6) : 1.0;
      return switch (snapshot.game.mode) {
        GameMode.sets => _SetsBoard(snapshot: snapshot, scale: scale),
        GameMode.cricket => SingleChildScrollView(child: CricketScorecard(snapshot: snapshot, scale: scale)),
        GameMode.counter when (snapshot.game.intSetting('periods') ?? 0) > 0 => Column(
            mainAxisSize: tv ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MatchClock(game: snapshot.game, state: snapshot.stateAs<CounterState>(), enabled: false),
              const SizedBox(height: Space.md),
              tv ? Expanded(child: _RankedBoard(snapshot: snapshot, scale: scale, tv: tv)) : _RankedBoard(snapshot: snapshot, scale: scale, tv: tv),
            ],
          ),
        _ => _RankedBoard(snapshot: snapshot, scale: scale, tv: tv),
      };
    });
  }
}

class _RankedBoard extends StatelessWidget {
  final GameSnapshot snapshot;
  final double scale;
  final bool tv;
  const _RankedBoard({required this.snapshot, required this.scale, required this.tv});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final gamePoint = game.mode == GameMode.counter && !snapshot.finished
        ? CounterEngine.onGamePoint(snapshot.stateAs<CounterState>(), game)
        : const <String>{};
    // Keyed rows keep their state (the change badge) when the order changes.
    return ListView(
      shrinkWrap: !tv,
      physics: tv ? null : const NeverScrollableScrollPhysics(),
      children: [
        for (final (i, s) in snapshot.standings.indexed)
          Padding(
            key: ValueKey(s.participantId),
            padding: EdgeInsets.only(top: i == 0 ? 0 : Space.sm * scale),
            child: _row(context, s, gamePoint.contains(s.participantId)),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Standing s, bool gamePoint) {
    final p = snapshot.game.participant(s.participantId)!;
    final leader = s.rank == 1 && !s.out;
    return AnimatedContainer(
      duration: motionMedium,
      padding: EdgeInsets.symmetric(horizontal: Space.lg * scale, vertical: Space.md * scale),
      decoration: BoxDecoration(
        color: leader ? context.scoreColors.gold.withValues(alpha: 0.12) : context.colors.surfaceContainerLow,
        borderRadius: Radii.mdAll,
        border: Border.all(color: leader ? context.scoreColors.gold : context.colors.outlineVariant),
      ),
      child: Opacity(
        opacity: s.out ? 0.5 : 1,
        child: Row(children: [
          RankBadge(rank: s.rank, size: 32 * scale),
          SizedBox(width: Space.md * scale),
          PlayerAvatar(name: p.name, color: p.color, size: 36 * scale),
          SizedBox(width: Space.md * scale),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(fontSize: 18 * scale, fontWeight: FontWeight.w700)),
                ),
                if (gamePoint) ...[SizedBox(width: Space.sm * scale), GamePointBadge(scale: scale)],
              ]),
              if (p.isTeam) Text(snapshot.membersLine(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(fontSize: 12 * scale)),
              if (s.detail.isNotEmpty) Text(s.detail, style: context.text.labelSmall?.copyWith(fontSize: 12 * scale)),
            ]),
          ),
          ScoreDelta(score: s.score, size: 20 * scale),
          SizedBox(width: Space.sm * scale),
          AnimatedSwitcher(
            duration: motionFast,
            child: Text(formatScore(s.score), key: ValueKey(s.score), style: scoreStyle(context, 40 * scale, color: playerColor(p.color))),
          ),
        ]),
      ),
    );
  }
}

class _SetsBoard extends StatelessWidget {
  final GameSnapshot snapshot;
  final double scale;
  const _SetsBoard({required this.snapshot, required this.scale});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final state = snapshot.stateAs<SetsState>();
    if (game.participants.length < 2) return const SizedBox();
    Widget side(int i) {
      final p = game.participants[i];
      final color = playerColor(p.color);
      return Expanded(
        child: Container(
          padding: EdgeInsets.all(Space.lg * scale),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: Radii.lgAll),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge?.copyWith(fontSize: 22 * scale)),
            SizedBox(height: Space.xs * scale),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (state.server == i && !snapshot.finished) Icon(Icons.sports_tennis, size: 18 * scale, color: color),
              SizedBox(width: Space.xs * scale),
              Text('Sets ${state.setsWon(i)}', style: context.text.labelLarge?.copyWith(fontSize: 14 * scale)),
            ]),
            Text('${state.current[i]}', style: scoreStyle(context, 96 * scale, color: color)),
            if (p.isTeam) Text(snapshot.membersLine(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(fontSize: 12 * scale)),
          ]),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [side(0), SizedBox(width: Space.md * scale), side(1)]),
      if (state.sets.isNotEmpty) ...[
        SizedBox(height: Space.md * scale),
        Wrap(spacing: Space.sm, children: [
          for (final s in state.sets) Chip(label: Text('${s[0]}–${s[1]}', style: scoreStyle(context, 14 * scale, weight: FontWeight.w600))),
        ]),
      ],
    ]);
  }
}
