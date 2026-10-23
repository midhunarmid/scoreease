import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/responsive.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../../../engine/rounds_engine.dart';
import '../../common/game_ui.dart';
import '../play_cubit.dart';

/// Score sheet: totals on top, one row per round, tap a row to fix it.
class RoundsView extends StatefulWidget {
  final GameSnapshot snapshot;
  final bool enabled;

  const RoundsView({super.key, required this.snapshot, required this.enabled});

  @override
  State<RoundsView> createState() => RoundsViewState();
}

class RoundsViewState extends State<RoundsView> {
  Future<void> addRound() => _openEntry();

  Future<void> _openEntry({int? editIndex}) async {
    if (!widget.enabled) return;
    final snapshot = widget.snapshot;
    final game = snapshot.game;
    final state = snapshot.stateAs<RoundsState>();
    final cubit = context.read<PlayCubit>();
    final players = editIndex == null ? RoundsEngine.active(state, game) : game.participants;
    final initial = editIndex == null ? const <String, int>{} : state.rounds[editIndex];
    final result = await showAdaptiveSheet<Map<String, int>>(
      context,
      builder: (_) => _RoundEntry(
        title: editIndex == null ? 'Round ${state.rounds.length + 1}' : 'Edit round ${editIndex + 1}',
        players: players,
        initial: initial,
      ),
    );
    if (result == null) return;
    if (editIndex == null) {
      cubit.add(RoundsEngine.round, {'s': result});
    } else {
      cubit.add(RoundsEngine.editRound, {'i': editIndex, 's': result});
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final game = snapshot.game;
    final state = snapshot.stateAs<RoundsState>();
    final dealer = RoundsEngine.dealer(state, game);
    final standingOf = {for (final s in snapshot.standings) s.participantId: s};
    final limits = [
      if (game.intSetting('eliminateAt') != null) 'Out at ${game.intSetting('eliminateAt')}',
      if (game.intSetting('target') != null) 'Ends at ${game.intSetting('target')}',
      if (game.intSetting('maxRounds') != null) '${game.intSetting('maxRounds')} rounds',
      game.flag('lowWins') ? 'Lowest wins' : 'Highest wins',
    ].join(' · ');

    return Scaffold(
      floatingActionButton: widget.enabled
          ? FloatingActionButton.extended(onPressed: addRound, icon: const Icon(Icons.playlist_add), label: const Text('Add round'))
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, 96),
        children: [
          Text(limits, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
          const SizedBox(height: Space.md),
          Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
            for (final p in game.participants)
              _TotalChip(
                participant: p,
                standing: standingOf[p.id]!,
                dealer: p.id == dealer && !snapshot.finished,
                eliminateAt: game.intSetting('eliminateAt'),
                started: state.rounds.isNotEmpty,
              ),
          ]),
          const SizedBox(height: Space.lg),
          if (state.rounds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxl),
              child: EmptyState(
                icon: Icons.table_rows_outlined,
                title: 'No rounds yet',
                message: widget.enabled ? 'Add the first round when it\'s played.' : 'Waiting for the first round.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) => Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    columnSpacing: Space.xl,
                    headingTextStyle: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    columns: [
                      const DataColumn(label: Text('#')),
                      for (final p in game.participants) DataColumn(numeric: true, label: Text(p.name, overflow: TextOverflow.ellipsis)),
                    ],
                    rows: [
                      for (var i = 0; i < state.rounds.length; i++)
                        DataRow(
                          onSelectChanged: widget.enabled ? (_) => _openEntry(editIndex: i) : null,
                          cells: [
                            DataCell(Text('${i + 1}')),
                            for (final p in game.participants)
                              DataCell(Text(state.rounds[i].containsKey(p.id) ? '${state.rounds[i][p.id]}' : '–', style: scoreStyle(context, 16, weight: FontWeight.w500))),
                          ],
                        ),
                      DataRow(
                        color: WidgetStatePropertyAll(context.colors.surfaceContainerHigh),
                        cells: [
                          const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
                          for (final p in game.participants) DataCell(Text('${state.totalOf(p.id)}', style: scoreStyle(context, 18))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          if (state.rounds.isNotEmpty && widget.enabled)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text('Tap a round to correct it.', style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  final Participant participant;
  final Standing standing;
  final bool dealer;
  final int? eliminateAt;
  final bool started;

  const _TotalChip({required this.participant, required this.standing, required this.dealer, this.eliminateAt, required this.started});

  @override
  Widget build(BuildContext context) {
    final out = standing.out;
    final leading = started && standing.rank == 1 && !out;
    return Opacity(
      opacity: out ? 0.5 : 1,
      child: Container(
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: Radii.mdAll,
          border: Border.all(color: leading ? context.scoreColors.gold : context.colors.outlineVariant, width: leading ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PlayerAvatar(name: participant.name, color: participant.color, size: 32),
          const SizedBox(width: Space.sm),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(participant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (dealer) ...[const SizedBox(width: 4), const Tooltip(message: 'Deals next', child: Text('🃏'))],
            ]),
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(formatScore(standing.score), style: scoreStyle(context, 24)),
              const SizedBox(width: Space.xs),
              Text(
                out ? 'OUT' : (eliminateAt != null ? '${eliminateAt! - standing.score.toInt()} left' : '#${standing.rank}'),
                style: context.text.labelSmall?.copyWith(color: out ? context.scoreColors.negative : context.colors.onSurfaceVariant),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class _RoundEntry extends StatefulWidget {
  final String title;
  final List<Participant> players;
  final Map<String, int> initial;

  const _RoundEntry({required this.title, required this.players, required this.initial});

  @override
  State<_RoundEntry> createState() => _RoundEntryState();
}

class _RoundEntryState extends State<_RoundEntry> {
  late final Map<String, TextEditingController> _controllers = {
    for (final p in widget.players) p.id: TextEditingController(text: widget.initial[p.id]?.toString() ?? ''),
  };
  late final Map<String, FocusNode> _focus = {for (final p in widget.players) p.id: FocusNode()};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _save() {
    final result = <String, int>{};
    for (final p in widget.players) {
      result[p.id] = int.tryParse(_controllers[p.id]!.text.trim()) ?? 0;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text('Blank counts as 0. Use − for negative points.', style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          const SizedBox(height: Space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(children: [
                for (var i = 0; i < widget.players.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Row(children: [
                      PlayerAvatar(name: widget.players[i].name, color: widget.players[i].color, size: 32),
                      const SizedBox(width: Space.md),
                      Expanded(child: Text(widget.players[i].name, style: context.text.titleSmall)),
                      IconButton(
                        tooltip: 'Make negative / positive',
                        icon: const Text('±', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          final c = _controllers[widget.players[i].id]!;
                          final v = int.tryParse(c.text.trim()) ?? 0;
                          c.text = v == 0 ? (c.text.startsWith('-') ? '' : '-') : '${-v}';
                          c.selection = TextSelection.collapsed(offset: c.text.length);
                        },
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _controllers[widget.players[i].id],
                          focusNode: _focus[widget.players[i].id],
                          autofocus: i == 0,
                          textAlign: TextAlign.end,
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,5}'))],
                          textInputAction: i == widget.players.length - 1 ? TextInputAction.done : TextInputAction.next,
                          style: scoreStyle(context, 20, weight: FontWeight.w600),
                          decoration: const InputDecoration(hintText: '0', isDense: true),
                          onSubmitted: (_) {
                            if (i == widget.players.length - 1) {
                              _save();
                            } else {
                              _focus[widget.players[i + 1].id]!.requestFocus();
                            }
                          },
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: Space.md),
          FilledButton(onPressed: _save, child: const Text('Save round')),
        ]),
      );
}
