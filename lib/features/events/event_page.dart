import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../app/router.dart';
import '../../data/local/local_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/event_scoring.dart';
import '../../engine/meet.dart';
import '../../engine/templates.dart';
import '../play/export.dart';
import 'event_data.dart';
import 'event_widgets.dart';

/// An event's home: team totals, its games, and who is doing best.
class EventPage extends StatelessWidget {
  final String id;
  const EventPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final store = getIt<LocalStore>();
    return StreamBuilder<void>(
      stream: store.meetChanges,
      builder: (context, _) => StreamBuilder<void>(
        stream: store.gameChanges,
        builder: (context, _) {
          final meet = store.meet(id);
          if (meet == null) {
            return Scaffold(
              appBar: AppBar(leading: BackButton(onPressed: () => goBack(context))),
              body: const ErrorState(title: 'Event not found', message: 'It may have been deleted.'),
            );
          }
          return _EventView(meet: meet, standings: loadMeetStandings(store, meet));
        },
      ),
    );
  }
}

enum _Action { announce, reopen, rename, points, csv, delete }

class _EventView extends StatelessWidget {
  final Meet meet;
  final MeetStandings standings;
  const _EventView({required this.meet, required this.standings});

  LocalStore get _store => getIt<LocalStore>();

  Future<void> _onAction(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.announce:
        final playing = standings.games.where((g) => !g.counted).length;
        final ok = meet.finished ||
            await confirm(
              context,
              title: 'Finish the event?',
              message: '${playing > 0 ? '$playing game${playing == 1 ? ' is' : 's are'} still going and won\'t count. ' : ''}You can reopen it later.',
              confirmLabel: 'Finish & announce',
            );
        if (!ok) return;
        await _store.saveMeet(meet.copyWith(finished: true, updatedAt: DateTime.now()));
        if (context.mounted) context.push('/event/${meet.id}/tv?announce=1');
      case _Action.reopen:
        await _store.saveMeet(meet.copyWith(finished: false, updatedAt: DateTime.now()));
      case _Action.rename:
        final name = await promptText(context, title: 'Rename event', initial: meet.name, confirmLabel: 'Save');
        if (name != null && name.trim().isNotEmpty) await _store.saveMeet(meet.copyWith(name: name.trim(), updatedAt: DateTime.now()));
      case _Action.points:
        final text = await promptText(
          context,
          title: 'Points for places',
          label: '1st, 2nd, 3rd...',
          initial: meet.placePoints,
          confirmLabel: 'Save',
          validator: (v) => RegExp(r'^\s*\d+(\s*,\s*\d+)*\s*$').hasMatch(v) ? null : 'Numbers separated by commas, e.g. 3,2,1',
        );
        if (text != null) await _store.saveMeet(meet.copyWith(placePoints: text.replaceAll(' ', ''), updatedAt: DateTime.now()));
      case _Action.csv:
        final name = meet.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
        await shareFile(context, Uint8List.fromList(utf8.encode(meetCsv(standings))), '$name.csv', 'text/csv');
      case _Action.delete:
        final ok = await confirm(
          context,
          title: 'Delete this event?',
          message: 'Its ${standings.games.length} game${standings.games.length == 1 ? '' : 's'} are deleted too. This can\'t be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await _store.deleteMeet(meet.id);
        if (context.mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    final addGame = FilledButton.icon(onPressed: () => context.push('/new?event=${meet.id}'), icon: const Icon(Icons.add), label: const Text('Add game'));
    final result = standings.resultText;

    final games = SectionCard(
      title: 'Games',
      trailing: wide ? addGame : null,
      child: standings.games.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Text('No games yet. Add the first one: musical chairs, a race, tug of war...', style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            )
          : Column(children: [
              for (final g in standings.games.reversed)
                Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: _GameRow(meet: meet, award: g)),
            ]),
    );
    final board = SectionCard(title: 'Top performers', child: EventLeaderboard(standings: standings));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => goBack(context)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meet.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            '🏆 Event · ${standings.games.length} game${standings.games.length == 1 ? '' : 's'} · ${_pointsLabel(meet.placePoints)}',
            style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'TV mode', onPressed: () => context.push('/event/${meet.id}/tv'), icon: const Icon(Icons.tv)),
          PopupMenuButton<_Action>(
            tooltip: 'More',
            onSelected: (a) => _onAction(context, a),
            itemBuilder: (_) => [
              PopupMenuItem(value: meet.finished ? _Action.reopen : _Action.announce, child: Text(meet.finished ? 'Reopen event' : 'Finish & announce')),
              const PopupMenuItem(value: _Action.rename, child: Text('Rename')),
              const PopupMenuItem(value: _Action.points, child: Text('Points for places')),
              const PopupMenuItem(value: _Action.csv, child: Text('Export CSV')),
              const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
      floatingActionButton: wide || meet.finished
          ? null
          : FloatingActionButton.extended(onPressed: () => context.push('/new?event=${meet.id}'), icon: const Icon(Icons.add), label: const Text('Add game')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, 96),
        children: [
          MaxWidth(
            maxWidth: 1100,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (meet.finished && result != null)
                Card(
                  color: context.colors.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.emoji_events, color: context.scoreColors.gold),
                    title: Text(result, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => context.push('/event/${meet.id}/tv?announce=1'),
                      icon: const Icon(Icons.campaign),
                      label: const Text('Announce'),
                    ),
                  ),
                ),
              const SizedBox(height: Space.sm),
              TeamTotals(standings: standings, scale: wide ? 1.2 : 1),
              const SizedBox(height: Space.lg),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: games),
                  const SizedBox(width: Space.lg),
                  Expanded(child: board),
                ])
              else ...[
                games,
                const SizedBox(height: Space.lg),
                board,
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

/// Short form of a points table for headers: "3-2-1 pts".
String _pointsLabel(String raw) => '${raw.replaceAll(',', '-')} pts';

class _GameRow extends StatelessWidget {
  final Meet meet;
  final GameAward award;
  const _GameRow({required this.meet, required this.award});

  @override
  Widget build(BuildContext context) {
    final game = award.game;
    final template = Templates.byId(game.templateId);
    return Card(
      child: ListTile(
        onTap: () => context.push('/game/${game.id}'),
        leading: Text(template.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(
          award.counted ? (award.teamPoints.isEmpty ? 'No points' : awardLine(meet, award.teamPoints)) : 'In progress · ${award.snapshot.summary}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: award.counted ? Icon(Icons.check_circle, color: context.scoreColors.positive) : const Icon(Icons.play_circle_outline),
      ),
    );
  }
}
