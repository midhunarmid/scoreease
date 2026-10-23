import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../data/local/local_store.dart';
import '../../design/responsive.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/engine.dart';
import '../../engine/templates.dart';
import '../common/game_ui.dart';

/// Every game on this device, searchable and filterable by template.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _store = getIt<LocalStore>();
  String _query = '';
  String? _template;
  bool _finishedOnly = false;

  bool _matches(Game g) {
    if (_template != null && g.templateId != _template) return false;
    if (_finishedOnly && !g.isFinished) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return g.title.toLowerCase().contains(q) ||
        g.participants.any((p) => p.name.toLowerCase().contains(q) || p.members.any((m) => m.toLowerCase().contains(q)));
  }

  Future<void> _delete(Game g) async {
    final ok = await confirm(context, title: 'Delete "${g.title}"?', confirmLabel: 'Delete', destructive: true);
    if (ok) await _store.deleteGame(g.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: StreamBuilder<void>(
          stream: _store.gameChanges,
          builder: (context, _) {
            final all = _store.games();
            final used = all.map((g) => g.templateId).toSet();
            final games = all.where(_matches).toList();
            return ListView(
              padding: EdgeInsets.fromLTRB(context.gutter, Space.sm, context.gutter, Space.xxl),
              children: [
                MaxWidth(
                  maxWidth: 900,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search games or players'),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: Space.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        FilterChip(label: const Text('Finished'), selected: _finishedOnly, onSelected: (v) => setState(() => _finishedOnly = v)),
                        const SizedBox(width: Space.sm),
                        for (final t in Templates.all.where((t) => used.contains(t.id))) ...[
                          ChoiceChip(
                            avatar: SizedBox(width: 18, child: Text(t.emoji, style: const TextStyle(fontSize: 14))),
                            showCheckmark: false,
                            label: Text(t.name),
                            selected: _template == t.id,
                            onSelected: (v) => setState(() => _template = v ? t.id : null),
                          ),
                          const SizedBox(width: Space.sm),
                        ],
                      ]),
                    ),
                    const SizedBox(height: Space.lg),
                    if (all.isEmpty)
                      const EmptyState(icon: Icons.history, title: 'No games yet', message: 'Games you play show up here, even offline.')
                    else if (games.isEmpty)
                      const EmptyState(icon: Icons.search_off, title: 'No matches')
                    else
                      for (final g in games)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: GameTile(
                            game: g,
                            onTap: () => context.push(gameRoute(g)),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'More',
                              onSelected: (a) {
                                if (a == 'rematch') context.push('/new?rematch=${g.id}');
                                if (a == 'delete') _delete(g);
                              },
                              itemBuilder: (_) => [
                                if (g.isOwner) const PopupMenuItem(value: 'rematch', child: Text('Rematch')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                        ),
                  ]),
                ),
              ],
            );
          },
        ),
      );
}
