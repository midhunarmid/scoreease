import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../play_cubit.dart';

/// Records a score and returns its event id, e.g. `() => cubit.add(...)`.
typedef ScoreAction = Future<String?> Function();

/// Lets a team card ask "who scored?" right after it scores, without getting
/// in the way: a strip of member chips shows for a few seconds and the tag
/// is saved when it closes. Ignoring it leaves the point untagged.
///
/// [builder] gets a `score` function to record a point through, and the
/// strip to place on the card (null while hidden).
class WhoScored extends StatefulWidget {
  final Participant team;
  final Widget Function(BuildContext context, void Function(ScoreAction action, int value) score, Widget? strip) builder;

  const WhoScored({super.key, required this.team, required this.builder});

  static const visibleFor = Duration(seconds: 6);

  @override
  State<WhoScored> createState() => _WhoScoredState();
}

class _WhoScoredState extends State<WhoScored> {
  late final PlayCubit _cubit;
  String? _target;
  Set<int> _selected = {};
  Timer? _timer;

  /// Stays up after the point that ends the game, so the winner can be
  /// tagged too. Viewers never get an event id, so never see it.
  bool get _active => widget.team.isTeam;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<PlayCubit>();
  }

  Future<void> _score(ScoreAction action, int value) async {
    _commit();
    final id = await action();
    if (!mounted || id == null || value <= 0 || !_active) return;
    setState(() {
      _target = id;
      _selected = {};
    });
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(WhoScored.visibleFor, () {
      _commit();
      if (mounted) setState(() {});
    });
  }

  /// Saves the current choice (if any) and hides the strip.
  void _commit() {
    _timer?.cancel();
    final target = _target;
    if (target != null && _selected.isNotEmpty) unawaited(_cubit.tag(target, _selected));
    _target = null;
    _selected = {};
  }

  void _toggle(Set<int> next) {
    setState(() => _selected = next);
    _restartTimer();
  }

  @override
  void dispose() {
    _commit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strip = _target == null
        ? null
        : _Strip(
            team: widget.team,
            selected: _selected,
            onChanged: _toggle,
            onDone: () => setState(_commit),
          );
    return widget.builder(context, _score, strip);
  }
}

class _Strip extends StatelessWidget {
  final Participant team;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final VoidCallback onDone;

  const _Strip({required this.team, required this.selected, required this.onChanged, required this.onDone});

  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.surfaceContainerHigh,
        borderRadius: Radii.smAll,
        child: SizedBox(
          height: 44,
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(left: Space.sm),
              child: Text('Who?', style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                child: MemberChips(team: team, selected: selected, onChanged: onChanged, dense: true),
              ),
            ),
            IconButton(tooltip: 'Done', visualDensity: VisualDensity.compact, onPressed: onDone, icon: const Icon(Icons.check)),
          ]),
        ),
      );
}

/// One chip per member playing plus "All". Used by the strip and the edit
/// sheet.
class MemberChips extends StatelessWidget {
  final Participant team;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  /// Single line, compact chips (for the strip); otherwise wraps.
  final bool dense;

  const MemberChips({super.key, required this.team, required this.selected, required this.onChanged, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final all = team.onCourt.toSet();
    final density = dense ? VisualDensity.compact : null;
    final chips = <Widget>[
      for (final i in all)
        FilterChip(
          visualDensity: density,
          avatar: PlayerAvatar(name: team.members[i], color: team.color, size: 20),
          showCheckmark: false,
          label: Text(team.members[i]),
          selected: selected.contains(i),
          onSelected: (on) => onChanged(on ? {...selected, i} : ({...selected}..remove(i))),
        ),
      if (all.length > 1)
        FilterChip(
          visualDensity: density,
          label: const Text('All'),
          selected: selected.length == all.length,
          onSelected: (on) => onChanged(on ? all : {}),
        ),
    ];
    return dense
        ? Row(children: [for (final c in chips) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: c)])
        : Wrap(spacing: Space.sm, runSpacing: Space.sm, children: chips);
  }
}

/// Opens a sheet to change who is credited with scoring event [eventId].
Future<void> editWhoScored(BuildContext context, GameSnapshot snapshot, String eventId) async {
  final credit = snapshot.creditable[eventId];
  // Whoever was playing then, not now.
  final team = credit == null ? null : snapshot.gameAt(eventId).participant(credit.pid);
  if (credit == null || team == null) return;
  final cubit = context.read<PlayCubit>();
  final result = await showAdaptiveSheet<Set<int>>(
    context,
    builder: (context) => _EditSheet(team: team, credit: credit, initial: snapshot.tags[eventId] ?? const {}),
  );
  if (result != null) await cubit.tag(eventId, result);
}

class _EditSheet extends StatefulWidget {
  final Participant team;
  final Credit credit;
  final Set<int> initial;
  const _EditSheet({required this.team, required this.credit, required this.initial});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late Set<int> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Who scored?', style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(
            '${widget.team.name} ${signed(widget.credit.v)} · everyone picked gets the points',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: Space.lg),
          MemberChips(team: widget.team, selected: _selected, onChanged: (s) => setState(() => _selected = s)),
          const SizedBox(height: Space.xl),
          Row(children: [
            if (widget.initial.isNotEmpty) TextButton(onPressed: () => Navigator.pop(context, <int>{}), child: const Text('Clear')),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: Space.sm),
            FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Save')),
          ]),
        ]),
      );
}
