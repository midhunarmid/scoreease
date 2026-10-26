import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/responsive.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../../../engine/placements_engine.dart';
import '../../common/game_ui.dart';
import '../play_cubit.dart';

/// An event team as the play screen shows it.
typedef TeamInfo = ({String name, int color});

/// Musical chairs and races: tap players as they go out (or finish). Players
/// still in are big tiles; placed players are listed by place.
class PlacementsView extends StatelessWidget {
  final GameSnapshot snapshot;
  final bool enabled;

  /// Event teams by id, to show each team's points so far. Empty outside
  /// events.
  final Map<String, TeamInfo> teams;

  const PlacementsView({super.key, required this.snapshot, required this.enabled, this.teams = const {}});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final state = snapshot.stateAs<PlacementsState>();
    final elimination = PlacementsEngine.isElimination(game);
    final remaining = PlacementsEngine.stillIn(state, game);
    final points = PlacementsEngine.placePointsOf(game);
    final placed = snapshot.standings.where((s) => s.rank > 0).toList()..sort((a, b) => a.rank.compareTo(b.rank));
    final nextPlace = elimination ? remaining.length : state.order.length + 1;
    final nextPoints = pointsForPlace(points, nextPlace);
    final cubit = context.read<PlayCubit>();

    final teamPoints = <String, int>{for (final id in teams.keys) id: 0};
    for (final s in snapshot.standings) {
      final team = game.participant(s.participantId)?.teamId;
      if (team != null && teamPoints.containsKey(team)) teamPoints[team] = teamPoints[team]! + s.score.toInt();
    }

    final hint = snapshot.finished
        ? null
        : '${elimination ? 'Tap who\'s out' : 'Tap who finishes next'} · ${ordinal(nextPlace)} place${nextPoints > 0 ? ', $nextPoints pt${nextPoints == 1 ? '' : 's'}' : ''}';

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (teamPoints.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Wrap(alignment: WrapAlignment.center, spacing: Space.sm, runSpacing: Space.sm, children: [
                  for (final MapEntry(key: id, value: pts) in teamPoints.entries)
                    Chip(
                      avatar: CircleAvatar(backgroundColor: playerColor(teams[id]!.color), radius: 8),
                      label: Text('${teams[id]!.name}  +$pts', style: scoreStyle(context, 16, weight: FontWeight.w700)),
                    ),
                ]),
              ),
            if (hint != null) Text(hint, textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ]),
        ),
      ),
      if (remaining.isNotEmpty && !snapshot.finished)
        SliverPadding(
          padding: EdgeInsets.all(context.isCompact ? Space.sm : Space.lg),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: context.isCompact ? 180 : 220,
              mainAxisExtent: 96,
              mainAxisSpacing: Space.sm,
              crossAxisSpacing: Space.sm,
            ),
            delegate: SliverChildBuilderDelegate(
              childCount: remaining.length,
              (context, i) {
                final p = remaining[i];
                final key = game.participants.indexOf(p) + 1;
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: Radii.mdAll, side: BorderSide(color: playerColor(p.color), width: 2)),
                  child: InkWell(
                    onTap: enabled ? () => cubit.add(PlacementsEngine.place, {'p': p.id}) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.sm),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        PlayerAvatar(name: p.name, color: p.color, size: 36),
                        const SizedBox(height: Space.xs),
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        if (key <= 9 && enabled) Text('Key $key', style: context.text.labelSmall?.copyWith(color: context.colors.outline)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      if (placed.isNotEmpty)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, Space.xxl),
          sliver: SliverList.list(children: [
            Text(elimination && !snapshot.finished ? 'Out' : 'Places', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Space.sm),
            for (final s in placed)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Card(
                  child: ListTile(
                    leading: RankBadge(rank: s.rank),
                    title: Row(children: [
                      PlayerAvatar(name: game.nameOf(s.participantId), color: game.participant(s.participantId)!.color, size: 24),
                      const SizedBox(width: Space.sm),
                      Flexible(child: Text(game.nameOf(s.participantId), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    subtitle: _teamName(game, s) == null ? null : Text(_teamName(game, s)!),
                    trailing: s.score > 0 ? Text('+${formatScore(s.score)}', style: scoreStyle(context, 20, color: context.scoreColors.positive)) : null,
                  ),
                ),
              ),
          ]),
        ),
    ]);
  }

  String? _teamName(Game game, Standing s) => teams[game.participant(s.participantId)?.teamId]?.name;
}
