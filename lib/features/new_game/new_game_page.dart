import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/di.dart';
import '../../app/router.dart';
import '../../data/local/local_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/engine.dart';
import '../../engine/templates.dart';
import '../home/home_page.dart';

const _maxParticipants = 50;

class _Draft {
  final TextEditingController name;
  int color;
  List<String> members;

  _Draft(String name, this.color, [this.members = const []]) : name = TextEditingController(text: name);
}

/// Pick a game, add players, tweak rules, start. One page that becomes two
/// columns on wide screens.
class NewGamePage extends StatefulWidget {
  final String? templateId;
  final String? rematchOf;

  const NewGamePage({super.key, this.templateId, this.rematchOf});

  @override
  State<NewGamePage> createState() => _NewGamePageState();
}

class _NewGamePageState extends State<NewGamePage> {
  final _store = getIt<LocalStore>();
  late GameTemplate _template;
  late Map<String, dynamic> _settings;
  final List<_Draft> _drafts = [];
  bool _teams = false;
  final _title = TextEditingController();
  bool _titleEdited = false;

  /// On phones the template grid is folded away once a template is chosen.
  late bool _pickTemplate = widget.templateId == null && widget.rematchOf == null;

  @override
  void initState() {
    super.initState();
    final rematch = widget.rematchOf == null ? null : _store.game(widget.rematchOf!);
    if (rematch != null) {
      _template = Templates.byId(rematch.templateId);
      _settings = Map.of(rematch.settings);
      for (final p in rematch.participants) {
        _drafts.add(_Draft(p.name, p.color, p.members));
      }
      _teams = rematch.participants.any((p) => p.isTeam);
      _title.text = rematch.title;
      _titleEdited = true;
    } else {
      _selectTemplate(Templates.byId(widget.templateId ?? 'counter'), initial: true);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    for (final d in _drafts) {
      d.name.dispose();
    }
    super.dispose();
  }

  void _selectTemplate(GameTemplate t, {bool initial = false}) {
    void apply() {
      _template = t;
      _settings = Map.of(t.settings);
      if (!_titleEdited) _title.text = '${t.name} · ${DateFormat.MMMd().format(DateTime.now())}';
      if (t.twoSides) {
        while (_drafts.length > 2) {
          _drafts.removeLast().name.dispose();
        }
        final defaults = t.teamsByDefault ? ['Team A', 'Team B'] : ['Player 1', 'Player 2'];
        while (_drafts.length < 2) {
          _drafts.add(_Draft(defaults[_drafts.length], _drafts.length));
        }
      }
      while (_drafts.length < 2) {
        _drafts.add(_Draft('', _drafts.length));
      }
      if (initial || t.teamsByDefault) _teams = t.teamsByDefault;
    }

    if (initial) {
      apply();
    } else {
      setState(apply);
    }
  }

  void _addParticipant([String name = '', int? color]) {
    if (_drafts.length >= _maxParticipants) return;
    setState(() => _drafts.add(_Draft(name, color ?? _nextColor())));
  }

  int _nextColor() {
    final used = _drafts.map((d) => d.color).toSet();
    for (var i = 0; i < playerPalette.length; i++) {
      if (!used.contains(i)) return i;
    }
    return _drafts.length;
  }

  /// Blank names fall back to their placeholder, so a game can start in one tap.
  String _nameAt(int i) {
    final name = _drafts[i].name.text.trim();
    return name.isNotEmpty ? name : '${_teams ? 'Team' : 'Player'} ${i + 1}';
  }

  String? _validate() {
    final names = [for (var i = 0; i < _drafts.length; i++) _nameAt(i)];
    if (names.isEmpty) return 'Add at least one ${_teams ? 'team' : 'player'}';
    if (_template.twoSides && names.length != 2) return 'This game needs exactly two sides';
    if (_template.mode == GameMode.rounds && _settings['eliminateAt'] != null && names.length < 2) return 'Elimination needs at least two players';
    if (names.map((n) => n.toLowerCase()).toSet().length != names.length) return 'Names must be different';
    return null;
  }

  Future<void> _start() async {
    final error = _validate();
    if (error != null) {
      toast(context, error);
      return;
    }
    final now = DateTime.now();
    final participants = [
      for (var i = 0; i < _drafts.length; i++)
        Participant(
          id: 'p$i',
          name: _nameAt(i),
          color: _drafts[i].color,
          members: _teams ? _drafts[i].members : const [],
        ),
    ];
    final game = Game(
      id: PushId.next(),
      title: _title.text.trim().isEmpty ? _template.name : _title.text.trim(),
      templateId: _template.id,
      mode: _template.mode,
      settings: Map.of(_settings)..removeWhere((_, v) => v == null),
      participants: participants,
      createdAt: now,
      updatedAt: now,
    );
    await _store.saveGame(game);
    await _store.saveEvents(game.id, const []);
    await _store.rememberPlayers(participants);
    if (mounted) context.pushReplacement('/game/${game.id}');
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.windowSize != WindowSize.compact;
    final templateSection = wide || _pickTemplate
        ? _TemplatePicker(selected: _template, onSelect: _selectTemplate)
        : SectionCard(
            title: 'Game',
            trailing: TextButton(onPressed: () => setState(() => _pickTemplate = true), child: const Text('Change')),
            child: SizedBox(height: 64, child: TemplateCard(template: _template, selected: true, onTap: () => setState(() => _pickTemplate = true))),
          );
    final titleField = TextField(
      controller: _title,
      decoration: const InputDecoration(labelText: 'Title'),
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => _titleEdited = true,
      inputFormatters: [LengthLimitingTextInputFormatter(60)],
    );
    final players = _ParticipantsSection(
      drafts: _drafts,
      teams: _teams,
      fixedTwo: _template.twoSides,
      onTeams: (v) => setState(() => _teams = v),
      onAdd: _addParticipant,
      onRemove: (d) => setState(() {
        _drafts.remove(d);
        d.name.dispose();
      }),
      onChanged: () => setState(() {}),
    );
    final options = _OptionsSection(
      template: _template,
      settings: _settings,
      sideNames: _drafts.map((d) => d.name.text.trim()).toList(),
      onChanged: () => setState(() {}),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => goBack(context)),
        title: Text(widget.rematchOf != null ? 'Rematch' : 'New game'),
        actions: [
          if (wide) Padding(padding: const EdgeInsets.only(right: Space.lg), child: FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('Start game'))),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
                child: FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('Start game')),
              ),
            ),
      body: ListView(
        padding: EdgeInsets.all(context.gutter),
        children: [
          MaxWidth(
            maxWidth: 1100,
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(children: [templateSection, const SizedBox(height: Space.lg), SectionCard(child: titleField)])),
                    const SizedBox(width: Space.xl),
                    Expanded(child: Column(children: [players, const SizedBox(height: Space.lg), options])),
                  ])
                : Column(children: [
                    templateSection,
                    const SizedBox(height: Space.lg),
                    players,
                    const SizedBox(height: Space.lg),
                    options,
                    const SizedBox(height: Space.lg),
                    SectionCard(child: titleField),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  final GameTemplate selected;
  final ValueChanged<GameTemplate> onSelect;
  const _TemplatePicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Game',
        child: LayoutBuilder(builder: (context, c) {
          final columns = (c.maxWidth / 200).floor().clamp(2, 4);
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 64,
              mainAxisSpacing: Space.sm,
              crossAxisSpacing: Space.sm,
            ),
            children: [
              for (final t in Templates.all) TemplateCard(template: t, selected: t.id == selected.id, onTap: () => onSelect(t)),
            ],
          );
        }),
      );
}

class _ParticipantsSection extends StatelessWidget {
  final List<_Draft> drafts;
  final bool teams;
  final bool fixedTwo;
  final ValueChanged<bool> onTeams;
  final void Function([String name, int? color]) onAdd;
  final ValueChanged<_Draft> onRemove;
  final VoidCallback onChanged;

  const _ParticipantsSection({
    required this.drafts,
    required this.teams,
    required this.fixedTwo,
    required this.onTeams,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = getIt<LocalStore>();
    final used = drafts.map((d) => d.name.text.trim().toLowerCase()).toSet();
    final suggestions = store.players().where((p) => !used.contains(p.name.toLowerCase())).take(12).toList();
    final noun = teams ? 'team' : 'player';

    return SectionCard(
      title: fixedTwo ? 'Sides' : (teams ? 'Teams' : 'Players'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Teams', style: context.text.labelLarge),
        const SizedBox(width: Space.xs),
        Switch(value: teams, onChanged: onTeams),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < drafts.length; i++)
          _ParticipantRow(
            key: ObjectKey(drafts[i]),
            draft: drafts[i],
            index: i,
            teams: teams,
            removable: !fixedTwo,
            onRemove: () => onRemove(drafts[i]),
            onChanged: onChanged,
            onSubmitted: !fixedTwo && i == drafts.length - 1 ? () => onAdd() : null,
          ),
        if (!fixedTwo)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: () => onAdd(), icon: const Icon(Icons.add), label: Text('Add $noun')),
          ),
        if (suggestions.isNotEmpty && !teams && !fixedTwo) ...[
          const SizedBox(height: Space.sm),
          Text('Recent players', style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
            for (final p in suggestions)
              ActionChip(
                avatar: PlayerAvatar(name: p.name, color: p.color, size: 24),
                label: Text(p.name),
                onPressed: () {
                  final blank = drafts.where((d) => d.name.text.trim().isEmpty).firstOrNull;
                  if (blank != null) {
                    blank.name.text = p.name;
                    blank.color = p.color;
                    onChanged();
                  } else {
                    onAdd(p.name, p.color);
                  }
                },
              ),
          ]),
        ],
      ]),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final _Draft draft;
  final int index;
  final bool teams;
  final bool removable;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;

  const _ParticipantRow({
    super.key,
    required this.draft,
    required this.index,
    required this.teams,
    required this.removable,
    required this.onRemove,
    required this.onChanged,
    this.onSubmitted,
  });

  Future<void> _addMember(BuildContext context) async {
    final name = await promptText(context, title: 'Add to ${draft.name.text.trim().isEmpty ? 'team' : draft.name.text.trim()}', label: 'Player name');
    if (name == null || name.trim().isEmpty) return;
    draft.members = [...draft.members, name.trim()];
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Tooltip(
              message: 'Change colour',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  draft.color = (draft.color + 1) % playerPalette.length;
                  onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.all(Space.xs),
                  child: PlayerAvatar(name: draft.name.text.isEmpty ? '${index + 1}' : draft.name.text, color: draft.color),
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextField(
                controller: draft.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: onSubmitted == null ? TextInputAction.done : TextInputAction.next,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                decoration: InputDecoration(hintText: teams ? 'Team ${index + 1}' : 'Player ${index + 1}', isDense: true),
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSubmitted?.call(),
              ),
            ),
            if (removable) IconButton(tooltip: 'Remove', icon: const Icon(Icons.remove_circle_outline), onPressed: onRemove),
          ]),
          if (teams)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: Space.xs),
              child: Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
                for (final m in draft.members)
                  InputChip(
                    label: Text(m),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () {
                      draft.members = [...draft.members]..remove(m);
                      onChanged();
                    },
                  ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Player'),
                  onPressed: () => _addMember(context),
                ),
              ]),
            ),
        ]),
      );
}

class _OptionsSection extends StatelessWidget {
  final GameTemplate template;
  final Map<String, dynamic> settings;
  final List<String> sideNames;
  final VoidCallback onChanged;

  const _OptionsSection({required this.template, required this.settings, required this.sideNames, required this.onChanged});

  Widget _number(String key, String label, {String? hint, bool optional = true, int min = 1, int max = 9999}) => _NumberField(
        key: ValueKey('${template.id}-$key'),
        label: label,
        hint: hint ?? (optional ? 'None' : null),
        initial: (settings[key] as num?)?.toInt(),
        min: min,
        max: max,
        onChanged: (v) {
          if (v == null && optional) {
            settings.remove(key);
          } else if (v != null) {
            settings[key] = v;
          }
          onChanged();
        },
      );

  Widget _switch(BuildContext context, String key, String label, String subtitle) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(subtitle),
        value: settings[key] == true,
        onChanged: (v) {
          settings[key] = v;
          onChanged();
        },
      );

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[];
    switch (template.mode) {
      case GameMode.counter:
        final countdown = settings['startAt'] != null;
        fields.addAll([
          _number('startAt', 'Count down from', hint: 'Count up from 0', max: 100000),
          if (!countdown) _number('target', 'Winning score', hint: 'No target'),
          if (!countdown && settings['target'] != null && settings['lowWins'] != true) _number('winBy', 'Must win by', hint: 'Any lead', max: 10),
          _StepsField(
            key: ValueKey('${template.id}-steps'),
            initial: settings['steps']?.toString() ?? '1',
            onChanged: (v) {
              settings['steps'] = v;
              onChanged();
            },
          ),
          _number('periods', 'Periods with a clock', hint: 'No clock', max: 12),
          if (settings['periods'] != null) _number('periodMinutes', 'Minutes per period', optional: false, max: 240),
          if (!countdown) _switch(context, 'lowWins', 'Lowest score wins', 'e.g. golf or penalty points'),
        ]);
      case GameMode.rounds:
        fields.addAll([
          _number('target', 'Game ends at total', hint: 'No target'),
          _number('eliminateAt', 'Player is out at', hint: 'No elimination'),
          _number('maxRounds', 'Number of rounds', hint: 'Unlimited', max: 200),
          _switch(context, 'lowWins', 'Lowest total wins', 'Rummy, golf, Hearts...'),
        ]);
      case GameMode.sets:
        fields.addAll([
          _number('points', 'Points to win a set', optional: false, max: 99),
          _BestOfField(
            key: ValueKey('${template.id}-sets'),
            setsToWin: (settings['sets'] as num?)?.toInt() ?? 2,
            onChanged: (v) {
              settings['sets'] = v;
              onChanged();
            },
          ),
          _number('winBy', 'Must win by', optional: false, max: 5),
          _number('cap', 'Point cap', hint: 'No cap', max: 99),
          _number('decidingPoints', 'Points in deciding set', hint: 'Same as others', max: 99),
          _number('serveEvery', 'Serve changes every', hint: 'Rally winner serves', max: 10),
        ]);
      case GameMode.cricket:
        fields.addAll([
          _number('overs', 'Overs per side', optional: false, max: 50),
          _number('wickets', 'Wickets', optional: false, max: 10),
          _SideChoice(
            label: 'Batting first',
            names: sideNames,
            value: (settings['battingFirst'] as num?)?.toInt() ?? 0,
            onChanged: (v) {
              settings['battingFirst'] = v;
              onChanged();
            },
          ),
        ]);
    }
    return SectionCard(
      title: 'Rules',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: Space.md), child: f),
      ]),
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final String? hint;
  final int? initial;
  final int min;
  final int max;
  final ValueChanged<int?> onChanged;

  const _NumberField({super.key, required this.label, this.hint, this.initial, required this.min, required this.max, required this.onChanged});

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, floatingLabelBehavior: FloatingLabelBehavior.always),
        onChanged: (text) {
          final v = int.tryParse(text);
          widget.onChanged(v?.clamp(widget.min, widget.max));
        },
      );
}

class _StepsField extends StatelessWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _StepsField({super.key, required this.initial, required this.onChanged});

  static const presets = {'1': '+1', '1,2,3': '+1 +2 +3', '1,5,10': '+1 +5 +10', '1,3': '+1 +3', '5,10,25': '+5 +10 +25'};

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Score buttons', style: context.text.labelLarge),
        const SizedBox(height: Space.xs),
        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
          for (final p in {...presets.keys, initial})
            ChoiceChip(label: Text(presets[p] ?? p.split(',').map((s) => '+$s').join(' ')), selected: p == initial, onSelected: (_) => onChanged(p)),
        ]),
      ]);
}

class _BestOfField extends StatelessWidget {
  final int setsToWin;
  final ValueChanged<int> onChanged;
  const _BestOfField({super.key, required this.setsToWin, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Match length', style: context.text.labelLarge),
        const SizedBox(height: Space.xs),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('1 set')),
            ButtonSegment(value: 2, label: Text('Best of 3')),
            ButtonSegment(value: 3, label: Text('Best of 5')),
            ButtonSegment(value: 4, label: Text('Best of 7')),
          ],
          selected: {setsToWin.clamp(1, 4)},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ]);
}

class _SideChoice extends StatelessWidget {
  final String label;
  final List<String> names;
  final int value;
  final ValueChanged<int> onChanged;
  const _SideChoice({required this.label, required this.names, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.text.labelLarge),
        const SizedBox(height: Space.xs),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var i = 0; i < 2; i++)
              ButtonSegment(value: i, label: Text(i < names.length && names[i].isNotEmpty ? names[i] : 'Side ${i + 1}', overflow: TextOverflow.ellipsis)),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ]);
}
