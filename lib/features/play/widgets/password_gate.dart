import 'package:flutter/material.dart';

import '../../../data/cloud/access_remote.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';

/// Full-screen password prompt for a protected live game.
class PasswordGate extends StatefulWidget {
  final AccessLevel level;
  final Future<bool> Function(String password) onUnlock;
  final VoidCallback onCancel;

  const PasswordGate({super.key, required this.level, required this.onUnlock, required this.onCancel});

  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  final _controller = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    bool ok;
    try {
      ok = await widget.onUnlock(_controller.text);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Wrong password';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scoring = widget.level != AccessLevel.read;
    return Scaffold(
      appBar: AppBar(leading: CloseButton(onPressed: widget.onCancel)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: context.colors.primaryContainer,
                child: Icon(Icons.lock_outline, size: 32, color: context.colors.onPrimaryContainer),
              ),
              const SizedBox(height: Space.lg),
              Text(scoring ? 'Scoring password' : 'Password needed', style: context.text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: Space.sm),
              Text(
                scoring ? 'Ask the organiser for the password to keep score.' : 'This game is private. Ask the organiser for the password.',
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.xl),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: _hidden,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _error,
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Unlock'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
