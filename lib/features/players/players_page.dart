import 'package:flutter/material.dart';

import '../../app/di.dart';
import '../../data/local/local_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/engine.dart';
import 'stats.dart';

/// Remembered players with their record across finished games.
class PlayersPage extends StatelessWidget {
  const PlayersPage({super.key});

  Future<void> _add(BuildContext context) async {
    final store = getIt<LocalStore>();
    final name = await promptText(context, title: 'Add player', label: 'Name', confirmLabel: 'Add');
    if (name == null || name.trim().isEmpty) return;
    final exists = store.players().any((p) => p.name.toLowerCase() == name.trim().toLowerCase());
    if (exists) {
      if (context.mounted) toast(context, '${name.trim()} is already in your list');
      return;
    }
    await store.savePlayer(SavedPlayer(id: PushId.next(), name: name.trim(), color: store.players().length % playerPalette.length, lastUsed: DateTime.now().millisecondsSinceEpoch));
  }

  Future<void> _edit(BuildContext context, SavedPlayer p) async {
    final store = getIt<LocalStore>();
    final action = await showAdaptiveSheet<String>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: PlayerAvatar(name: p.name, color: p.color), title: Text(p.name, style: context.text.titleMedium)),
          const Divider(),
          ListTile(leading: const Icon(Icons.edit), title: const Text('Rename'), onTap: () => Navigator.pop(context, 'rename')),
          ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('Change colour'), onTap: () => Navigator.pop(context, 'color')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove from list'), onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        final name = await promptText(context, title: 'Rename', initial: p.name, confirmLabel: 'Save');
        if (name != null && name.trim().isNotEmpty) await store.savePlayer(p.copyWith(name: name.trim()));
      case 'color':
        await store.savePlayer(p.copyWith(color: (p.color + 1) % playerPalette.length));
      case 'delete':
        await store.deletePlayer(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = getIt<LocalStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Players'), actions: [
        IconButton(tooltip: 'Add player', onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt)),
        const SizedBox(width: Space.sm),
      ]),
      body: StreamBuilder<void>(
        stream: store.playerChanges,
        builder: (context, _) => StreamBuilder<void>(
          stream: store.gameChanges,
          builder: (context, _) {
            final players = store.players()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            final stats = computeStats(store.games());
            if (players.isEmpty) {
              return EmptyState(
                icon: Icons.people_outline,
                title: 'No players yet',
                message: 'Players are remembered when you start a game, so you can pick them in one tap next time.',
                action: FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt), label: const Text('Add player')),
              );
            }
            final leaders = players.where((p) => (stats[p.name.toLowerCase()]?.played ?? 0) > 0).toList()
              ..sort((a, b) => (stats[b.name.toLowerCase()]!.wins).compareTo(stats[a.name.toLowerCase()]!.wins));
            return ListView(
              padding: EdgeInsets.fromLTRB(context.gutter, Space.sm, context.gutter, Space.xxl),
              children: [
                MaxWidth(
                  maxWidth: 900,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (leaders.isNotEmpty) ...[
                      Text('Most wins', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: Space.sm),
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: leaders.length.clamp(0, 5),
                          separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
                          itemBuilder: (context, i) {
                            final p = leaders[i];
                            final s = stats[p.name.toLowerCase()]!;
                            return SizedBox(
                              width: 150,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(Space.md),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      PlayerAvatar(name: p.name, color: p.color, size: 28),
                                      const SizedBox(width: Space.sm),
                                      Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge)),
                                    ]),
                                    const Spacer(),
                                    Text('${s.wins}', style: scoreStyle(context, 28, color: context.scoreColors.forRank(i + 1))),
                                    Text('wins · ${(s.winRate * 100).round()}%', style: context.text.labelSmall),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                    ],
                    Text('Everyone', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: Space.sm),
                    Card(
                      child: Column(children: [
                        for (final p in players) _PlayerRow(player: p, stats: stats[p.name.toLowerCase()], onTap: () => _edit(context, p)),
                      ]),
                    ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final SavedPlayer player;
  final PlayerStats? stats;
  final VoidCallback onTap;
  const _PlayerRow({required this.player, required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return ListTile(
      onTap: onTap,
      leading: PlayerAvatar(name: player.name, color: player.color),
      title: Text(player.name),
      subtitle: Text(
        s == null || s.played == 0
            ? 'No finished games yet'
            : '${s.played} played · ${s.wins} won${s.bestStreak > 1 ? ' · best streak ${s.bestStreak}' : ''}',
      ),
      trailing: s == null || s.played == 0 ? null : Text('${(s.winRate * 100).round()}%', style: scoreStyle(context, 18)),
    );
  }
}
