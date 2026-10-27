import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../../../engine/sets_engine.dart';
import '../play_cubit.dart';
import '../widgets/who_scored.dart';

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
    final courts = SetsEngine.tracksCourts(game) && !snapshot.finished;
    final doubles = courts && SetsEngine.isDoubles(game);

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
      if (courts)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
          child: doubles
              ? _MiniCourt(snapshot: snapshot, enabled: enabled, fresh: fresh)
              : Text(SetsEngine.serveLine(state, game), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final horizontal = c.maxWidth > c.maxHeight * 0.9;
          final sides = [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: WhoScored(
                  team: game.participants[i],
                  builder: (context, score, strip) => _Side(
                    participant: game.participants[i],
                    points: state.current[i],
                    setsWon: state.setsWon(i),
                    serving: state.server == i && !snapshot.finished,
                    serveNote: doubles
                        ? state.server == i
                            ? '${game.participants[i].members[state.serverMember]} serving · ${state.serveFromRight ? 'right' : 'left'}'
                            : '${game.participants[i].members[state.receiverMember]} receiving'
                        : null,
                    winner: snapshot.winners.contains(game.participants[i].id),
                    enabled: enabled,
                    onPoint: () => score(() => cubit.add(SetsEngine.point, {'p': game.participants[i].id}), 1),
                    onServe: enabled && fresh ? () => cubit.add(SetsEngine.serve, {'p': game.participants[i].id}) : null,
                    strip: strip,
                  ),
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

  /// Doubles: "Ann serving · right" or "Dee receiving".
  final String? serveNote;
  final bool winner;
  final bool enabled;
  final VoidCallback onPoint;
  final VoidCallback? onServe;

  /// "Who scored?" chips for a team, shown briefly after a point.
  final Widget? strip;

  const _Side({
    required this.participant,
    required this.points,
    required this.setsWon,
    required this.serving,
    this.serveNote,
    required this.winner,
    required this.enabled,
    required this.onPoint,
    this.onServe,
    this.strip,
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
              if (strip != null) ...[strip!, const SizedBox(height: Space.xs)],
              SizedBox(
                height: 32,
                child: serving
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.sports_tennis, size: 18, color: color),
                        const SizedBox(width: Space.xs),
                        Text(serveNote ?? 'Serving', style: context.text.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
                      ])
                    : onServe != null
                        ? TextButton(onPressed: onServe, child: const Text('Serves first'))
                        : serveNote != null
                            ? Center(child: Text(serveNote!, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)))
                            : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Badminton doubles: a small court showing who stands where, with the
/// server filled in and the receiver diagonally opposite outlined. At 0-0
/// tapping a player picks the server or receiver; mid-game the swap buttons
/// fix a service court error without touching the score.
class _MiniCourt extends StatelessWidget {
  final GameSnapshot snapshot;
  final bool enabled;
  final bool fresh;

  const _MiniCourt({required this.snapshot, required this.enabled, required this.fresh});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final state = snapshot.stateAs<SetsState>();
    final cubit = context.read<PlayCubit>();
    final right = state.serveFromRight;
    final serverSide = state.server;

    void pick(int side, int member) => cubit.add(SetsEngine.serve, {
          'p': game.participants[serverSide].id,
          'm': side == serverSide ? member : state.serverMember,
          'r': side == serverSide ? state.receiverMember : member,
        });

    // Side 0 plays from the left facing right, so its right court is the
    // lower box; side 1 faces left, so its right court is the upper one.
    // The two right courts are then diagonal, like on a real court.
    Widget cell(int side, bool rightCourt) {
      final p = game.participants[side];
      final member = state.memberIn(side, right: rightCourt);
      final active = rightCourt == right;
      final isServer = active && side == serverSide;
      final isReceiver = active && side != serverSide;
      final color = playerColor(p.color);
      final name = p.members[member];
      return Expanded(
        child: Material(
          color: isServer ? color : color.withValues(alpha: isReceiver ? 0.22 : 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: Radii.smAll,
            side: isReceiver ? BorderSide(color: color, width: 2) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled && fresh ? () => pick(side, member) : null,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                child: AnimatedSwitcher(
                  duration: motionFast,
                  child: Row(key: ValueKey('$name$isServer$isReceiver'), mainAxisSize: MainAxisSize.min, children: [
                    if (isServer) ...[const Icon(Icons.sports_tennis, size: 14, color: Colors.white), const SizedBox(width: 2)],
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelLarge?.copyWith(
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: isServer ? Colors.white : null,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget swap(int side) => IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Swap ${game.participants[side].name} courts',
          icon: const Icon(Icons.swap_vert),
          onPressed: enabled && !fresh ? () => cubit.add(SetsEngine.positions, {'p': game.participants[side].id}) : null,
        );

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(SetsEngine.serveLine(state, game), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      if (fresh && enabled)
        Text('Tap a player to pick who serves and receives', style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
      const SizedBox(height: Space.xs),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          height: 72,
          child: Row(children: [
            swap(0),
            Expanded(child: Column(children: [cell(0, false), const SizedBox(height: 2), cell(0, true)])),
            Container(width: 3, margin: const EdgeInsets.symmetric(horizontal: Space.xs), color: context.colors.outline),
            Expanded(child: Column(children: [cell(1, true), const SizedBox(height: 2), cell(1, false)])),
            swap(1),
          ]),
        ),
      ),
    ]);
  }
}
