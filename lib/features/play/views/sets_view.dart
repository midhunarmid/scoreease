import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../../../engine/sets_engine.dart';
import '../play_cubit.dart';

/// Two big halves; tap a side to give it the rally.
class SetsView extends StatelessWidget {
  final GameSnapshot snapshot;
  final bool enabled;

  const SetsView({super.key, required this.snapshot, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    if (game.participants.length < 2) return const EmptyState(icon: Icons.error_outline, title: 'This game needs two sides');
    final state = snapshot.stateAs<SetsState>();
    final cubit = context.read<PlayCubit>();
    final fresh = state.current[0] + state.current[1] == 0;
    final deciding = SetsEngine.isDecidingSet(state, game);
    final target = SetsEngine.pointsForSet(state, game);
    final need = SetsEngine.setsToWin(game);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: Space.sm, runSpacing: Space.xs, children: [
          Text(
            snapshot.finished ? 'Final' : 'Set ${state.sets.length + 1}${deciding ? ' · deciding' : ''} · to $target',
            style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          for (var i = 0; i < state.sets.length; i++)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${state.sets[i][0]}–${state.sets[i][1]}', style: scoreStyle(context, 14, weight: FontWeight.w600)),
            ),
          if (need > 1) Text('First to $need sets', style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ]),
      ),
      if (fresh && state.sets.isNotEmpty && !snapshot.finished)
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Text('↔ Switch ends', style: context.text.labelLarge?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w700)),
        ),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final horizontal = c.maxWidth > c.maxHeight * 0.9;
          final sides = [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: _Side(
                  participant: game.participants[i],
                  points: state.current[i],
                  setsWon: state.setsWon(i),
                  serving: state.server == i && !snapshot.finished,
                  winner: snapshot.winners.contains(game.participants[i].id),
                  enabled: enabled,
                  onPoint: () => cubit.add(SetsEngine.point, {'p': game.participants[i].id}),
                  onServe: enabled && fresh ? () => cubit.add(SetsEngine.serve, {'p': game.participants[i].id}) : null,
                ),
              ),
          ];
          return Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: horizontal
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [sides[0], const SizedBox(width: Space.sm), sides[1]])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [sides[0], const SizedBox(height: Space.sm), sides[1]]),
          );
        }),
      ),
    ]);
  }
}

class _Side extends StatelessWidget {
  final Participant participant;
  final int points;
  final int setsWon;
  final bool serving;
  final bool winner;
  final bool enabled;
  final VoidCallback onPoint;
  final VoidCallback? onServe;

  const _Side({
    required this.participant,
    required this.points,
    required this.setsWon,
    required this.serving,
    required this.winner,
    required this.enabled,
    required this.onPoint,
    this.onServe,
  });

  @override
  Widget build(BuildContext context) {
    final color = playerColor(participant.color);
    return Semantics(
      button: enabled,
      label: '${participant.name}, $points points, $setsWon sets${serving ? ', serving' : ''}. Tap to add a point.',
      child: Material(
        color: color.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.22 : 0.12),
        shape: RoundedRectangleBorder(borderRadius: Radii.lgAll, side: BorderSide(color: winner ? context.scoreColors.gold : Colors.transparent, width: 3)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPoint : null,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(children: [
              Row(children: [
                PlayerAvatar(name: participant.name, color: participant.color, size: 28),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(participant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                  decoration: BoxDecoration(color: color, borderRadius: Radii.smAll),
                  child: Text('Sets $setsWon', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]),
              Expanded(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: AnimatedSwitcher(
                      duration: motionFast,
                      transitionBuilder: (child, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: child)),
                      child: Text('$points', key: ValueKey(points), style: scoreStyle(context, 140, color: color)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: serving
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.sports_tennis, size: 18, color: color),
                        const SizedBox(width: Space.xs),
                        Text('Serving', style: context.text.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
                      ])
                    : onServe != null
                        ? TextButton(onPressed: onServe, child: const Text('Serves first'))
                        : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
