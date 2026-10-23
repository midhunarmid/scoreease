import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/responsive.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Destination(this.icon, this.selectedIcon, this.label);
}

const _destinations = [
  _Destination(Icons.scoreboard_outlined, Icons.scoreboard, 'Games'),
  _Destination(Icons.history_outlined, Icons.history, 'History'),
  _Destination(Icons.people_outline, Icons.people, 'Players'),
  _Destination(Icons.settings_outlined, Icons.settings, 'Settings'),
];

/// Bottom navigation on phones, a rail on tablets and an extended rail on
/// desktop and web.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  void _select(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    if (size == WindowSize.compact) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      );
    }

    final extended = size == WindowSize.expanded;
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: extended,
          minExtendedWidth: 200,
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.lg),
            child: Column(children: [
              _Brand(extended: extended),
              const SizedBox(height: Space.lg),
              extended
                  ? FilledButton.icon(onPressed: () => context.push('/new'), icon: const Icon(Icons.add), label: const Text('New game'))
                  : FloatingActionButton(
                      elevation: 0,
                      tooltip: 'New game',
                      onPressed: () => context.push('/new'),
                      child: const Icon(Icons.add),
                    ),
            ]),
          ),
          destinations: [
            for (final d in _destinations)
              NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: shell),
      ]),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool extended;
  const _Brand({required this.extended});

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: Radii.smAll,
      child: Image.asset('assets/images/brand_icon.png', width: 36, height: 36),
    );
    if (!extended) return logo;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      logo,
      const SizedBox(width: Space.sm),
      Text('ScoreEase', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }
}
