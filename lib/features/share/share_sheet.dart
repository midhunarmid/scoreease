import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/cloud/cloud.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../common/game_ui.dart';
import '../play/play_cubit.dart';

Future<void> showShareSheet(BuildContext context, PlayCubit cubit) => showAdaptiveSheet(
      context,
      builder: (_) => BlocProvider.value(value: cubit, child: const _ShareSheet()),
    );

class _ShareSheet extends StatefulWidget {
  const _ShareSheet();

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _read = TextEditingController();
  final _write = TextEditingController();
  bool _busy = false;
  bool _editPasswords = false;
  bool _tv = false;

  @override
  void dispose() {
    _read.dispose();
    _write.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) toast(context, e is CloudException ? e.message : 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayCubit>().state;
    final code = state.liveCode;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
      child: code == null ? _notShared(context) : _shared(context, code),
    );
  }

  Widget _passwordFields() => Column(children: [
        _PasswordField(controller: _read, label: 'View password', hint: 'Anyone with the link can watch'),
        const SizedBox(height: Space.md),
        _PasswordField(controller: _write, label: 'Scoring password', hint: 'Anyone who can watch can score'),
      ]);

  Widget _notShared(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Share live', style: context.text.titleLarge),
        const SizedBox(height: Space.sm),
        Text(
          'Friends follow the score on their phone, laptop or TV as it happens. Add passwords to keep it private or to let others keep score.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.lg),
        _passwordFields(),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(() => context.read<PlayCubit>().share(readPassword: _read.text, writePassword: _write.text)),
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cell_tower),
          label: const Text('Go live'),
        ),
      ]);

  Widget _shared(BuildContext context, String code) {
    final link = _tv ? tvLink(code) : liveLink(code);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Text('Live now', style: context.text.titleLarge), const SizedBox(width: Space.sm), const LiveBadge()]),
      const SizedBox(height: Space.lg),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, icon: Icon(Icons.smartphone), label: Text('Follow link')),
          ButtonSegment(value: true, icon: Icon(Icons.tv), label: Text('TV link')),
        ],
        selected: {_tv},
        onSelectionChanged: (s) => setState(() => _tv = s.first),
      ),
      const SizedBox(height: Space.sm),
      Text(
        _tv ? 'Opens straight into the big-screen scoreboard. Watch only.' : 'Opens the live page, where people can watch or keep score.',
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
      ),
      const SizedBox(height: Space.md),
      Center(
        child: Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(color: Colors.white, borderRadius: Radii.mdAll),
          child: QrImageView(data: link, size: 180, backgroundColor: Colors.white),
        ),
      ),
      const SizedBox(height: Space.md),
      Center(child: SelectableText(code.toUpperCase(), style: scoreStyle(context, 36).copyWith(letterSpacing: 6))),
      Center(child: Text('Join code', style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant))),
      const SizedBox(height: Space.sm),
      Center(child: SelectableText(link.replaceFirst('https://', ''), style: context.text.bodySmall)),
      const SizedBox(height: Space.lg),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) toast(context, _tv ? 'TV link copied' : 'Link copied');
            },
            icon: const Icon(Icons.link),
            label: const Text('Copy link'),
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => SharePlus.instance.share(ShareParams(uri: Uri.parse(link), subject: _tv ? 'Live scoreboard for the TV' : 'Follow the score live')).ignore(),
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ),
      ]),
      const SizedBox(height: Space.lg),
      const Divider(),
      if (!_editPasswords)
        TextButton.icon(onPressed: () => setState(() => _editPasswords = true), icon: const Icon(Icons.lock_outline), label: const Text('Change passwords'))
      else ...[
        const SizedBox(height: Space.md),
        Text('Leave blank to remove a password.', style: context.text.bodySmall),
        const SizedBox(height: Space.sm),
        _passwordFields(),
        const SizedBox(height: Space.md),
        FilledButton.tonal(
          onPressed: _busy
              ? null
              : () {
                  final cubit = context.read<PlayCubit>();
                  _run(() async {
                    await cubit.setPasswords(read: _read.text, write: _write.text);
                    if (!mounted) return;
                    setState(() => _editPasswords = false);
                    toast(this.context, 'Passwords updated');
                  });
                },
          child: const Text('Save passwords'),
        ),
      ],
      TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: context.colors.error),
        onPressed: _busy
            ? null
            : () async {
                final cubit = context.read<PlayCubit>();
                final ok = await confirm(
                  context,
                  title: 'Stop sharing?',
                  message: 'The link stops working. The game stays on this device.',
                  confirmLabel: 'Stop sharing',
                  destructive: true,
                );
                if (ok) await _run(cubit.stopSharing);
              },
        icon: const Icon(Icons.portable_wifi_off),
        label: const Text('Stop sharing'),
      ),
    ]);
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _PasswordField({required this.controller, required this.label, required this.hint});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: _hidden,
        inputFormatters: [LengthLimitingTextInputFormatter(64)],
        decoration: InputDecoration(
          labelText: '${widget.label} (optional)',
          helperText: widget.hint,
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Show' : 'Hide',
            icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      );
}
