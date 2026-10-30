import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di.dart';
import '../../../data/local/local_store.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/counter_engine.dart';
import '../../../engine/engine.dart';
import '../../../engine/lineup.dart';
import '../../../engine/meet.dart';
import '../play_cubit.dart';

Future<void> showPlayersSheet(BuildContext context) {
  final cubit = context.read<PlayCubit>();
  return showAdaptiveSheet(context, builder: (_) => BlocProvider.value(value: cubit, child: const PlayersSheet()));
}

/// Everyone in a game, with what can still be changed about them.
class PlayersSheet extends StatelessWidget {
  const PlayersSheet({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<PlayCubit, PlayState>(
        builder: (context, state) {
          final snapshot = state.snapshot;
          return snapshot == null ? const SizedBox() : _Lineup(snapshot: snapshot);
        },
      );
}

class _Lineup extends StatelessWidget {
  final GameSnapshot snapshot;
  const _Lineup({required this.snapshot});

  Game get _game => snapshot.game;
  Meet? get _meet => _game.eventId == null ? null : getIt<LocalStore>().meet(_game.eventId!);

  /// Who could come on for [side]: its own bench, then the event, then people
  /// remembered on this device.
  List<String> _suggestions(Participant? side) {
    final meet = _meet;
    final playing = [for (final p in _game.sides) ...(p.isTeam ? p.onCourt.map((i) => p.members[i]) : [p.name])];
    final out = <String>[];
    void offer(String name) {
      if (![...playing, ...out].any((n) => sameName(n, name))) out.add(name);
    }

    side?.everyone.forEach(offer);
    meet?.team(side?.teamId)?.members.forEach(offer);
    for (final t in meet?.teams ?? const <MeetTeam>[]) {
      t.members.forEach(offer);
    }
    for (final p in getIt<LocalStore>().players()) {
      offer(p.name);
    }
    return out.take(12).toList();
  }

  /// Everyone named anywhere in the game, side names included.
  List<String> get _names => [for (final p in _game.current) ...[p.name, ...p.everyone]];

  Future<void> _fixSpelling(BuildContext context, String name) async {
    final cubit = context.read<PlayCubit>();
    final fixed = await promptText(
      context,
      title: 'Fix spelling',
      label: 'Name',
      initial: name,
      confirmLabel: 'Save',
      validator: (v) {
        final text = v.trim();
        if (text.isEmpty) return 'Enter a name';
        if (text.length > maxNameLength) return 'At most $maxNameLength characters';
        final clash = !sameName(text, name) && _names.any((n) => sameName(n, text));
        return clash ? '$text is already in this game' : null;
      },
    );
    if (fixed != null && fixed.trim() != name) await cubit.renameName(name, fixed.trim());
  }

  Future<void> _swap(BuildContext context, Participant side, {int? out}) async {
    final cubit = context.read<PlayCubit>();
    final leaving = out == null ? side.name : side.members[out];
    final onSide = side.isTeam ? side.onCourt.map((i) => side.members[i]) : [side.name];
    final name = await _pickName(
      context,
      title: 'Swap out $leaving',
      suggestions: _suggestions(side),
      validator: (text) => onSide.any((n) => sameName(n, text)) ? '$text is already playing here' : null,
    );
    if (name != null) await cubit.substitute(side.id, out: out, name: name);
  }

  Future<void> _addMember(BuildContext context, Participant team) async {
    final cubit = context.read<PlayCubit>();
    final name = await _pickName(
      context,
      title: 'Add to ${team.name}',
      suggestions: _suggestions(team),
      validator: (text) => team.onCourt.any((i) => sameName(team.members[i], text)) ? '$text is already playing here' : null,
    );
    if (name != null) await cubit.substitute(team.id, name: name);
  }

  Future<void> _removeMember(BuildContext context, Participant team, int member) async {
    final cubit = context.read<PlayCubit>();
    final ok = await confirm(
      context,
      title: 'Take ${team.members[member]} off ${team.name}?',
      message: 'Their points stay. You can undo this.',
      confirmLabel: 'Remove',
    );
    if (ok) await cubit.substitute(team.id, out: member);
  }

  Future<void> _retire(BuildContext context, Participant side) async {
    final cubit = context.read<PlayCubit>();
    final ok = await confirm(
      context,
      title: 'Retire ${side.name}?',
      message: 'They stop playing and can\'t win. Their score stays on the board. You can undo this.',
      confirmLabel: 'Retire',
    );
    if (ok) await cubit.retireSide(side.id);
  }

  int get _nextColor {
    final used = _game.current.map((p) => p.color).toSet();
    for (var i = 0; i < playerPalette.length; i++) {
      if (!used.contains(i)) return i;
    }
    return _game.current.length;
  }

  String? _nameFree(String text) => _game.sides.any((p) => sameName(p.name, text)) ? '$text is already playing' : null;

  Future<void> _addSide(BuildContext context) async {
    final cubit = context.read<PlayCubit>();
    final meet = _meet;
    if (_game.current.any((p) => p.isTeam)) {
      await (meet == null ? _addNewTeam(context, cubit) : _addEventTeam(context, cubit, meet));
      return;
    }
    final name = await _pickName(context, title: 'Add player', suggestions: _suggestions(null), validator: _nameFree);
    if (name == null) return;
    final team = meet?.teamOf(name);
    await cubit.addSide(name, color: team?.color ?? _nextColor, teamId: team?.id);
  }

  Future<void> _addEventTeam(BuildContext context, PlayCubit cubit, Meet meet) async {
    final free = meet.teams.where((t) => !_game.sides.any((p) => p.teamId == t.id)).toList();
    if (free.isEmpty) {
      toast(context, 'Every team in the event is already playing');
      return;
    }
    final name = await _pickName(
      context,
      title: 'Add team',
      suggestions: [for (final t in free) t.name],
      validator: (text) => free.any((t) => sameName(t.name, text)) ? null : 'Pick a team from the event',
    );
    if (name == null) return;
    final team = free.firstWhere((t) => sameName(t.name, name));
    await cubit.addSide(team.name, color: team.color, teamId: team.id, members: team.members);
  }

  Future<void> _addNewTeam(BuildContext context, PlayCubit cubit) async {
    final name = await _pickName(context, title: 'Add team', suggestions: const [], validator: _nameFree);
    if (name == null || !context.mounted) return;
    final people = await promptText(
      context,
      title: 'Players in $name',
      label: 'Names, separated by commas',
      confirmLabel: 'Add team',
      validator: (v) => _split(v).any((n) => n.length > maxNameLength) ? 'Names can have at most $maxNameLength characters' : null,
    );
    if (people != null) await cubit.addSide(name, color: _nextColor, members: _split(people));
  }

  List<String> _split(String text) => text.split(',').map((n) => n.trim()).where((n) => n.isNotEmpty).toList();

  String get _note {
    if (snapshot.canSub) {
      final start = _game.mode == GameMode.counter ? CounterEngine.startOf(_game) : 0;
      return 'Swapping keeps the score, and earlier points stay with whoever scored them.'
          '${snapshot.canChangeSides ? ' Anyone added starts from $start.' : ''}';
    }
    return snapshot.finished ? 'The game has ended, so only spelling can be fixed.' : 'Places have started, so only spelling can be fixed.';
  }

  @override
  Widget build(BuildContext context) {
    final teams = _game.current.any((p) => p.isTeam);
    final canRetire = snapshot.canChangeSides && _game.sides.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Players', style: context.text.titleLarge),
        const SizedBox(height: Space.xs),
        Text(_note, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: Space.sm),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (final side in _game.current) ..._rows(context, side, canRetire: canRetire),
          ]),
        ),
        if (snapshot.canChangeSides) ...[
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(onPressed: () => _addSide(context), icon: const Icon(Icons.add), label: Text(teams ? 'Add team' : 'Add player')),
        ],
      ]),
    );
  }

  List<Widget> _rows(BuildContext context, Participant side, {required bool canRetire}) {
    final canSwap = snapshot.canSub && !side.retired;
    final retire = canRetire && !side.retired ? _action(Icons.logout, 'Retire', () => _retire(context, side)) : null;
    final fix = _action(Icons.edit_outlined, 'Fix spelling', () => _fixSpelling(context, side.name));
    if (!side.isTeam) {
      return [
        _Person(
          name: side.name,
          color: side.color,
          note: side.retired ? 'Retired' : (side.former.isEmpty ? null : 'Replaced ${side.former.join(', ')}'),
          actions: [if (canSwap) _action(Icons.swap_horiz, 'Swap', () => _swap(context, side)), fix, if (retire != null) retire],
        ),
      ];
    }
    final court = side.onCourt;
    final canResize = canSwap && !snapshot.fixedTeams;
    return [
      _Person(name: side.name, color: side.color, note: side.retired ? 'Retired' : null, actions: [fix, if (retire != null) retire]),
      for (final (i, m) in side.members.indexed)
        Padding(
          padding: const EdgeInsets.only(left: Space.xl),
          child: _Person(
            name: m,
            color: side.color,
            note: court.contains(i) ? null : 'Swapped out',
            actions: [
              if (canSwap && court.contains(i)) _action(Icons.swap_horiz, 'Swap', () => _swap(context, side, out: i)),
              _action(Icons.edit_outlined, 'Fix spelling', () => _fixSpelling(context, m)),
              if (canResize && court.contains(i) && court.length > 1)
                _action(Icons.person_remove_outlined, 'Remove', () => _removeMember(context, side, i)),
            ],
          ),
        ),
      if (canResize)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: Space.xl),
            child: TextButton.icon(onPressed: () => _addMember(context, side), icon: const Icon(Icons.person_add_alt), label: Text('Add to ${side.name}')),
          ),
        ),
    ];
  }

  Widget _action(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton(tooltip: tooltip, visualDensity: VisualDensity.compact, onPressed: onPressed, icon: Icon(icon));
}

class _Person extends StatelessWidget {
  final String name;
  final int color;
  final String? note;
  final List<Widget> actions;

  const _Person({required this.name, required this.color, this.note, required this.actions});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Opacity(opacity: note == null ? 1 : 0.5, child: PlayerAvatar(name: name, color: color, size: 28)),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: note == null ? null : Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
}

/// Asks for a name, offering [suggestions]. Returns null when cancelled.
Future<String?> _pickName(
  BuildContext context, {
  required String title,
  required List<String> suggestions,
  required String? Function(String) validator,
}) =>
    showAdaptiveSheet<String>(context, builder: (_) => _NamePicker(title: title, suggestions: suggestions, validator: validator));

class _NamePicker extends StatefulWidget {
  final String title;
  final List<String> suggestions;
  final String? Function(String) validator;

  const _NamePicker({required this.title, required this.suggestions, required this.validator});

  @override
  State<_NamePicker> createState() => _NamePickerState();
}

class _NamePickerState extends State<_NamePicker> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final text = value.trim();
    final error = text.isEmpty
        ? 'Enter a name'
        : text.length > maxNameLength
            ? 'At most $maxNameLength characters'
            : widget.validator(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: _submit,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
              for (final name in widget.suggestions) ActionChip(label: Text(name), onPressed: () => _submit(name)),
            ]),
          ],
          const SizedBox(height: Space.lg),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: Space.sm),
            FilledButton(onPressed: () => _submit(_name.text), child: const Text('Save')),
          ]),
        ]),
      );
}
