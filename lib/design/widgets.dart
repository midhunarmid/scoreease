import 'package:flutter/material.dart';

import 'responsive.dart';
import 'theme.dart';
import 'tokens.dart';

/// Coloured circle with a name's initial.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final int color;
  final double size;

  const PlayerAvatar({super.key, required this.name, required this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final bg = playerColor(color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.42),
      ),
    );
  }
}

/// A titled group of content.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(Space.lg)});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Row(children: [
                  Expanded(child: Text(title!, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  if (trailing != null) trailing!,
                ]),
                const SizedBox(height: Space.md),
              ],
              child,
            ],
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 56, color: context.colors.primary.withValues(alpha: 0.7)),
              const SizedBox(height: Space.lg),
              Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: Space.sm),
                Text(message!, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: Space.xl), action!],
            ]),
          ),
        ),
      );
}

class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          if (message != null) ...[const SizedBox(height: Space.lg), Text(message!, style: context.text.bodyMedium)],
        ]),
      );
}

class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, this.title = 'Something went wrong', required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.error_outline,
        title: title,
        message: message,
        action: onRetry == null ? null : FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
      );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: context.colors.onError) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void toast(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action, duration: const Duration(seconds: 3)));
}

/// Asks for a single line of text. Returns null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? label,
  String initial = '',
  bool obscure = false,
  String confirmLabel = 'OK',
  TextInputType? keyboardType,
  String? Function(String)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      obscure: obscure,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
      validator: validator,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  final String title;
  final String? label;
  final String initial;
  final bool obscure;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final String? Function(String)? validator;

  const _PromptDialog({
    required this.title,
    this.label,
    required this.initial,
    required this.obscure,
    required this.confirmLabel,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  late bool _hidden = widget.obscure;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = widget.validator?.call(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _hidden,
            keyboardType: widget.keyboardType,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _error,
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden ? 'Show' : 'Hide',
                      icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
        ],
      );
}

/// Shows [builder] as a bottom sheet on phones and a dialog on wider screens.
Future<T?> showAdaptiveSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: builder(context),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(padding: const EdgeInsets.only(top: Space.lg), child: builder(context)),
      ),
    ),
  );
}
