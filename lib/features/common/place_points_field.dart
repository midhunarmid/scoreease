import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/placements_engine.dart';

/// Picks the points for 1st, 2nd, 3rd... as "3,2,1".
class PlacePointsField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  const PlacePointsField({super.key, required this.value, required this.onChanged, this.label = 'Points for places'});

  static const presets = ['3,2,1', '5,3,1', '10,6,4,2,1', '1'];

  static String describe(String raw) {
    final points = parsePlacePoints(raw);
    return [for (final (i, p) in points.indexed) '${ordinal(i + 1)} $p'].join(' · ');
  }

  Future<void> _custom(BuildContext context) async {
    final text = await promptText(
      context,
      title: 'Points for places',
      label: '1st, 2nd, 3rd...',
      initial: value,
      confirmLabel: 'Use',
      validator: (v) => RegExp(r'^\s*\d+(\s*,\s*\d+)*\s*$').hasMatch(v) ? null : 'Numbers separated by commas, e.g. 5,3,1',
    );
    if (text != null) onChanged(parsePlacePoints(text).join(','));
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.text.labelLarge),
        const SizedBox(height: Space.xs),
        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
          for (final p in {...presets, value})
            ChoiceChip(label: Text(p.replaceAll(',', ' · ')), selected: p == value, onSelected: (_) => onChanged(p)),
          ActionChip(avatar: const Icon(Icons.edit, size: 18), label: const Text('Custom'), onPressed: () => _custom(context)),
        ]),
        const SizedBox(height: Space.xs),
        Text(describe(value), style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
      ]);
}
