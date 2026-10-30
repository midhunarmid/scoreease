import 'package:flutter/material.dart';

import '../../app/di.dart';
import '../../app/router.dart';
import '../../data/cloud/live_board_remote.dart';
import '../../data/local/local_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/engine.dart';
import '../../engine/lineup.dart';
import '../../engine/meet.dart';
import 'event_data.dart';

/// Change an event's teams: rename, add, remove, move or swap people. Games
/// already played keep their results.
class EventRosterPage extends StatelessWidget {
  final String id;
  const EventRosterPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final store = getIt<LocalStore>();
    return StreamBuilder<void>(
      stream: store.meetChanges,
      builder: (context, _) {
        final meet = store.meet(id);
        if (meet == null) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => goBack(context))),
            body: const ErrorState(title: 'Event not found', message: 'It may have been deleted.'),
          );
        }
        return _RosterView(meet: meet);
      },
    );
  }
}

class _RosterView extends StatelessWidget {
  final Meet meet;
  const _RosterView({required this.meet});

  LocalStore get _store => getIt<LocalStore>();

  Future<void> _save(Meet next) => _store.saveMeet(next.copyWith(updatedAt: DateTime.now()));

  bool _alone(MeetTeam team) => team.members.length <= 1;

  void _needsOne(BuildContext context) => toast(context, 'Every team needs at least one player');

  /// Blank, too long or already used by someone else in the event.
  String? _checkName(String value, {String? was}) {
    final text = value.trim();
    if (text.isEmpty) return 'Enter a name';
    if (text.length > maxNameLength) return 'At most $maxNameLength characters';
    final taken = was == null || !sameName(text, was);
    if (taken && meet.teams.any((t) => sameName(t.name, text) || t.members.any((m) => sameName(m, text)))) return '$text is already in this event';
    return null;
  }

  Future<void> _rename(BuildContext context, String name, String title) async {
    final fixed = await promptText(context, title: title, label: 'Name', initial: name, confirmLabel: 'Save', validator: (v) => _checkName(v, was: name));
    if (fixed == null || fixed.trim() == name) return;
    await renameInEvent(_store, meet, name, fixed.trim(), send: (code, event) => getIt<LiveBoardRemote>().addEvent(code, event));
  }

  Future<void> _add(BuildContext context, MeetTeam team) async {
    final name = await promptText(context, title: 'Add to ${team.name}', label: 'Name', confirmLabel: 'Add', validator: _checkName);
    if (name == null) return;
    await _save(meet.withPerson(name.trim(), team.id));
    await _store.rememberPlayers([Participant(id: name.trim(), name: name.trim(), color: team.color)]);
  }

  Future<void> _open(BuildContext context, MeetTeam team, String person) async {
    final others = meet.teams.where((t) => t.id != team.id).toList();
    final action = await showAdaptiveSheet<String>(
      context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(person, style: context.text.titleLarge)),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Fix spelling'), onTap: () => Navigator.pop(context, 'rename')),
          for (final t in others)
            ListTile(leading: const Icon(Icons.drive_file_move_outline), title: Text('Move to ${t.name}'), onTap: () => Navigator.pop(context, 'move:${t.id}')),
          if (others.isNotEmpty) ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('Swap with…'), onTap: () => Navigator.pop(context, 'swap')),
          ListTile(leading: const Icon(Icons.person_remove_outlined), title: const Text('Remove from event'), onTap: () => Navigator.pop(context, 'remove')),
        ]),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'rename':
        await _rename(context, person, 'Fix spelling');
      case 'swap':
        final other = await _pickPerson(context, person, others);
        if (other != null) await _save(meet.swapped(person, other));
      case 'remove':
        if (_alone(team)) return _needsOne(context);
        final ok = await confirm(
          context,
          title: 'Remove $person?',
          message: 'They won\'t be offered for new games. Games they already played keep their results.',
          confirmLabel: 'Remove',
          destructive: true,
        );
        if (ok) await _save(meet.without(person));
      default:
        if (_alone(team)) return _needsOne(context);
        await _save(meet.moved(person, action.substring('move:'.length)));
    }
  }

  Future<String?> _pickPerson(BuildContext context, String person, List<MeetTeam> teams) => showAdaptiveSheet<String>(
        context,
        builder: (context) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            ListTile(title: Text('Swap $person with', style: context.text.titleLarge)),
            for (final t in teams)
              for (final m in t.members)
                ListTile(
                  leading: PlayerAvatar(name: m, color: t.color, size: 28),
                  title: Text(m),
                  subtitle: Text(t.name),
                  onTap: () => Navigator.pop(context, m),
                ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => goBack(context, '/event/${meet.id}')),
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Teams & players'),
            Text(meet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ]),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, Space.xxl),
          children: [
            MaxWidth(
              maxWidth: 720,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Changes apply to new games. Games already played keep their results, but fixed spellings show everywhere.',
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.md),
                for (final t in meet.teams) ...[
                  SectionCard(
                    title: t.name,
                    trailing: IconButton(
                      tooltip: 'Rename ${t.name}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _rename(context, t.name, 'Rename team'),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                      for (final m in t.members)
                        ActionChip(
                          avatar: PlayerAvatar(name: m, color: t.color, size: 20),
                          label: Text(m),
                          onPressed: () => _open(context, t, m),
                        ),
                      ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Player'), onPressed: () => _add(context, t)),
                    ]),
                  ),
                  const SizedBox(height: Space.md),
                ],
              ]),
            ),
          ],
        ),
      );
}
