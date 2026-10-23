import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scoreease/core/utils/theme.dart';

/// Shown for any URL that doesn't match a route.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.scoreboard_outlined, size: 72, color: appColors.primaryColor),
                const SizedBox(height: 24),
                Text(
                  "Page not found",
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "This link doesn't lead to a scoreboard. Check the address, or open a scoreboard by its ID from the home page.",
                  style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text("Go to home"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
