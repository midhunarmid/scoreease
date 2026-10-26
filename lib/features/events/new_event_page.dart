import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/di.dart';
import '../../app/router.dart';
import '../../data/local/local_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/meet.dart';
import '../../engine/models.dart';
import '../common/place_points_field.dart';

const _maxTeams = 6;
const _defaultNames = ['Reds', 'Blues', 'Greens', 'Golds', 'Purples', 'Oranges'];

class _TeamDraft {
  final TextEditingController name;
  int color;
  List<String> members;

  _TeamDraft(String name, this.color) : name = TextEditingController(text: name), members = [];
}

/// Sets up an event: teams, who is on them, and the points for places.
class NewEventPage extends StatefulWidget {
  const NewEventPage({super.key});

  @override
  State<NewEventPage> createState() => _NewEventPageState();
}

class _NewEventPageState extends State<NewEventPage> {
  final _store = getIt<LocalStore>();
  final _name = TextEditingController(text: 'Games day');
  final _people = TextEditingController();
  final _teams = [_TeamDraft(_defaultNames[0], 1), _TeamDraft(_defaultNames[1], 0)];
  String _points = '3,2,1';

  @override
  void dispose() {
    _name.dispose();
    _people.dispose();
    for (final t in _teams) {
      t.name.dispose();
    }
    super.dispose();
  }

  /// Names typed or pasted into the big box, one per line or comma separated.
  List<String> get _typed {
    final seen = <String>{};
    return [
      for (final raw in _people.text.split(RegExp(r'[\n,;]+')))
        if (raw.trim().isNotEmpty && seen.add(raw.trim().toLowerCase())) raw.trim(),
    ];
  }

  List<String> get _everyone => [for (final t in _teams) ...t.members];

  void _split() {
    final people = {..._everyone, ..._typed}.toList();
    if (people.length < _teams.length) {
      toast(context, 'Add at least ${_teams.length} names first');
      return;
    }
    final split = splitEvenly(people, _teams.length);
    setState(() {
      for (var i = 0; i < _teams.length; i++) {
        _teams[i].members = split[i];
      }
      _people.clear();
    });
  }

  /// Adds the typed names to [team] as they are.
  void _addTypedTo(_TeamDraft team) {
    final taken = _everyone.map((n) => n.toLowerCase()).toSet();
    final fresh = _typed.where((n) => !taken.contains(n.toLowerCase())).toList();
    if (fresh.isEmpty) return;
    setState(() {
      team.members = [...team.members, ...fresh];
      _people.clear();
    });
  }

  Future<void> _addOne(_TeamDraft team) async {
    final name = await promptText(context, title: 'Add to ${team.name.text.trim()}', label: 'Name');
    if (name == null || name.trim().isEmpty) return;
    if (_everyone.any((n) => n.toLowerCase() == name.trim().toLowerCase())) {
      if (mounted) toast(context, '${name.trim()} is already on a team');
      return;
    }
    setState(() => team.members = [...team.members, name.trim()]);
  }

  /// Moves [person] to the next team, for quick fixes after a random split.
  void _move(_TeamDraft from, String person) {
    final to = _teams[(_teams.indexOf(from) + 1) % _teams.length];
    setState(() {
      from.members = [...from.members]..remove(person);
      to.members = [...to.members, person];
    });
  }

  String? _validate() {
    final names = _teams.map((t) => t.name.text.trim().toLowerCase()).toList();
    if (names.any((n) => n.isEmpty)) return 'Give every team a name';
    if (names.toSet().length != names.length) return 'Team names must be different';
    if (_teams.any((t) => t.members.isEmpty)) return 'Every team needs at least one player';
    return null;
  }

  Future<void> _create() async {
    final error = _validate();
    if (error != null) {
      toast(context, error);
      return;
    }
    final now = DateTime.now();
    final meet = Meet(
      id: PushId.next(),
      name: _name.text.trim().isEmpty ? 'Games day' : _name.text.trim(),
      teams: [
        for (final (i, t) in _teams.indexed) MeetTeam(id: 't$i', name: t.name.text.trim(), color: t.color, members: t.members),
      ],
      placePoints: _points,
      createdAt: now,
      updatedAt: now,
    );
    await _store.saveMeet(meet);
    await _store.rememberPlayers([for (final t in meet.teams) for (final m in t.members) Participant(id: m, name: m, color: t.color)]);
    if (mounted) context.pushReplacement('/event/${meet.id}');
  }

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    final typedCount = _typed.length;
    final people = SectionCard(
      title: 'People',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _people,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Type or paste names, one per line', alignLabelWithHint: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.md),
        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
          FilledButton.icon(
            onPressed: typedCount + _everyone.length >= _teams.length ? _split : null,
            icon: const Icon(Icons.shuffle),
            label: Text(_everyone.isEmpty ? 'Split randomly' : 'Reshuffle everyone'),
          ),
          for (final t in _teams)
            OutlinedButton(onPressed: typedCount > 0 ? () => _addTypedTo(t) : null, child: Text('Add to ${t.name.text.trim()}')),
        ]),
        const SizedBox(height: Space.sm),
        Text(
          '${_everyone.length} on teams${typedCount > 0 ? ' · $typedCount waiting' : ''}',
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ]),
    );

    final teams = SectionCard(
      title: 'Teams',
      trailing: _teams.length < _maxTeams
          ? TextButton.icon(
              onPressed: () => setState(() => _teams.add(_TeamDraft(_defaultNames[_teams.length], _teams.length))),
              icon: const Icon(Icons.add),
              label: const Text('Team'),
            )
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final t in _teams)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: _TeamEditor(
              key: ObjectKey(t),
              team: t,
              removable: _teams.length > 2,
              onRemove: () => setState(() {
                _teams.remove(t);
                _people.text = [..._typed, ...t.members].join('\n');
                t.name.dispose();
              }),
              onChanged: () => setState(() {}),
              onAdd: () => _addOne(t),
              onTapMember: (m) => _move(t, m),
              onRemoveMember: (m) => setState(() => t.members = [...t.members]..remove(m)),
            ),
          ),
        Text('Tap a name to move it to the next team.', style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
      ]),
    );

    final rules = SectionCard(
      title: 'Scoring',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PlacePointsField(value: _points, onChanged: (v) => setState(() => _points = v)),
        const SizedBox(height: Space.sm),
        Text(
          'In every game, places earn these points for the player and their team. Team games give them to the team. Each game can change them.',
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ]),
    );

    final name = SectionCard(
      child: TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Event name'),
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [LengthLimitingTextInputFormatter(60)],
      ),
    );

    final create = FilledButton.icon(onPressed: _create, icon: const Icon(Icons.emoji_events), label: const Text('Create event'));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => goBack(context)),
        title: const Text('New event'),
        actions: [if (wide) Padding(padding: const EdgeInsets.only(right: Space.lg), child: create)],
      ),
      bottomNavigationBar: wide ? null : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md), child: create)),
      body: ListView(
        padding: EdgeInsets.all(context.gutter),
        children: [
          MaxWidth(
            maxWidth: 1100,
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(children: [name, const SizedBox(height: Space.lg), people, const SizedBox(height: Space.lg), rules])),
                    const SizedBox(width: Space.xl),
                    Expanded(child: teams),
                  ])
                : Column(children: [
                    name,
                    const SizedBox(height: Space.lg),
                    people,
                    const SizedBox(height: Space.lg),
                    teams,
                    const SizedBox(height: Space.lg),
                    rules,
                  ]),
          ),
        ],
      ),
    );
  }
}

class _TeamEditor extends StatelessWidget {
  final _TeamDraft team;
  final bool removable;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<String> onTapMember;
  final ValueChanged<String> onRemoveMember;

  const _TeamEditor({
    super.key,
    required this.team,
    required this.removable,
    required this.onRemove,
    required this.onChanged,
    required this.onAdd,
    required this.onTapMember,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Tooltip(
            message: 'Change colour',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                team.color = (team.color + 1) % playerPalette.length;
                onChanged();
              },
              child: Padding(padding: const EdgeInsets.all(Space.xs), child: PlayerAvatar(name: team.name.text, color: team.color)),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: TextField(
              controller: team.name,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              decoration: const InputDecoration(isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text('${team.members.length}', style: scoreStyle(context, 20, color: playerColor(team.color))),
          if (removable) IconButton(tooltip: 'Remove team', onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline)),
        ]),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          for (final m in team.members)
            InputChip(
              label: Text(m),
              visualDensity: VisualDensity.compact,
              onPressed: () => onTapMember(m),
              onDeleted: () => onRemoveMember(m),
            ),
          ActionChip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Player'),
            onPressed: onAdd,
          ),
        ]),
      ]);
}
