import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../data/local/local_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/engine.dart';
import '../../engine/meet.dart';
import '../../engine/templates.dart';
import '../common/game_ui.dart';
import '../events/event_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = getIt<LocalStore>();
    return StreamBuilder<void>(
      stream: store.meetChanges,
      builder: (context, _) => StreamBuilder<void>(
        stream: store.gameChanges,
        builder: (context, _) {
          final games = store.games();
          final meets = store.meets();
          final active = games.where((g) => !g.isFinished).toList();
          final recent = games.where((g) => g.isFinished).take(5).toList();
          final wide = context.windowSize != WindowSize.compact;

          return Scaffold(
            appBar: AppBar(
              title: Row(children: [
                if (context.isCompact) ...[
                  ClipRRect(borderRadius: Radii.smAll, child: Image.asset('assets/images/brand_icon.png', width: 28, height: 28)),
                  const SizedBox(width: Space.sm),
                ],
                Text(context.isCompact ? 'ScoreEase' : 'Games'),
              ]),
              actions: [
                TextButton.icon(onPressed: () => showJoinDialog(context), icon: const Icon(Icons.login), label: const Text('Join')),
                const SizedBox(width: Space.sm),
              ],
            ),
            floatingActionButton: context.isCompact && games.isNotEmpty
                ? FloatingActionButton.extended(onPressed: () => context.push('/new'), icon: const Icon(Icons.add), label: const Text('New game'))
                : null,
            body: games.isEmpty && meets.isEmpty
                ? _Welcome(wide: wide)
                : ListView(
                    padding: EdgeInsets.fromLTRB(context.gutter, Space.sm, context.gutter, 96),
                    children: [
                      MaxWidth(
                        maxWidth: 1100,
                        child: wide
                            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(flex: 3, child: _GameLists(active: active, recent: recent, meets: meets)),
                                const SizedBox(width: Space.xl),
                                const Expanded(flex: 2, child: _QuickStart(columns: 2)),
                              ])
                            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                const _QuickStartStrip(),
                                const SizedBox(height: Space.xl),
                                _GameLists(active: active, recent: recent, meets: meets),
                              ]),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _GameLists extends StatelessWidget {
  final List<Game> active;
  final List<Game> recent;
  final List<Meet> meets;
  const _GameLists({required this.active, required this.recent, required this.meets});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Header('Events', action: TextButton.icon(onPressed: () => context.push('/events/new'), icon: const Icon(Icons.add), label: const Text('New event'))),
        if (meets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(
              'Running a games day with teams? An event adds up points from every game.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        for (final m in meets.take(3)) Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: EventTile(meet: m)),
        const SizedBox(height: Space.lg),
        _Header('In progress', count: active.length),
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text('No games in progress. Start one from the templates.', style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
        for (final g in active) Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: GameTile(game: g, onTap: () => context.push(gameRoute(g)))),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          _Header('Recently finished', action: TextButton(onPressed: () => context.go('/history'), child: const Text('See all'))),
          for (final g in recent) Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: GameTile(game: g, onTap: () => context.push(gameRoute(g)))),
        ],
      ]);
}

/// An event in lists: its name and the team totals.
class EventTile extends StatelessWidget {
  final Meet meet;
  const EventTile({super.key, required this.meet});

  @override
  Widget build(BuildContext context) {
    final standings = loadMeetStandings(getIt<LocalStore>(), meet);
    return Card(
      child: InkWell(
        onTap: () => context.push('/event/${meet.id}'),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.colors.tertiaryContainer, borderRadius: Radii.mdAll),
              child: const Text('🏆', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (meet.finished && standings.resultText != null) '🏆 ${standings.resultText}',
                    standings.rankedTeams.map((t) => '${t.name} ${standings.teamTotals[t.id]}').join(' · '),
                  ].join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ]),
            ),
            const SizedBox(width: Space.sm),
            Text('${standings.games.length} games', style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? action;
  const _Header(this.title, {this.count, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Row(children: [
          Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (count != null && count! > 0) ...[
            const SizedBox(width: Space.sm),
            Badge(label: Text('$count'), backgroundColor: context.colors.primary),
          ],
          const Spacer(),
          if (action != null) action!,
        ]),
      );
}

/// Template cards for starting a game in one tap.
class _QuickStart extends StatelessWidget {
  final int columns;
  const _QuickStart({required this.columns});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Header('Start a game'),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 68,
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
          ),
          children: [for (final t in Templates.all) TemplateCard(template: t, onTap: () => context.push('/new?template=${t.id}'))],
        ),
      ]);
}

class _QuickStartStrip extends StatelessWidget {
  const _QuickStartStrip();

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Header('Start a game', action: TextButton(onPressed: () => context.push('/new'), child: const Text('All'))),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: Templates.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final t = Templates.all[i];
              return SizedBox(width: 168, child: TemplateCard(template: t, onTap: () => context.push('/new?template=${t.id}')));
            },
          ),
        ),
      ]);
}

class TemplateCard extends StatelessWidget {
  final GameTemplate template;
  final VoidCallback onTap;
  final bool selected;

  const TemplateCard({super.key, required this.template, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) => Card(
        color: selected ? context.colors.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: selected ? context.colors.primary : context.colors.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(children: [
              Text(template.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(template.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(template.blurb, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _Welcome extends StatelessWidget {
  final bool wide;
  const _Welcome({required this.wide});

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.all(context.gutter),
        children: [
          MaxWidth(
            maxWidth: 900,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: Space.xl),
              Text('Keep score of anything.', style: context.text.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: Space.sm),
              Text(
                'Board games, card nights, table tennis, cricket. Works offline and shares live when you want it to.',
                style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.xxl),
              _QuickStart(columns: wide ? 3 : 2),
              const SizedBox(height: Space.xl),
              Center(
                child: Wrap(alignment: WrapAlignment.center, spacing: Space.sm, runSpacing: Space.sm, children: [
                  OutlinedButton.icon(onPressed: () => showJoinDialog(context), icon: const Icon(Icons.login), label: const Text('Join a live game')),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/events/new'),
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: const Text('Plan an event with teams'),
                  ),
                ]),
              ),
            ]),
          ),
        ],
      );
}

Future<void> showJoinDialog(BuildContext context) async {
  final input = await promptText(
    context,
    title: 'Join a live game',
    label: 'Code or link',
    confirmLabel: 'Join',
    validator: (v) => parseJoinCode(v) == null ? 'Enter the 6-character code or paste the link' : null,
  );
  if (input == null || !context.mounted) return;
  final code = parseJoinCode(input)!;
  if (code.startsWith('legacy:')) {
    context.push('/display?id=${code.substring(7)}');
  } else {
    context.push('/live/$code');
  }
}
