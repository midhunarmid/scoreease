import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/widgets.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.explore_off_outlined,
          title: 'Page not found',
          message: 'That link doesn\'t lead anywhere.',
          action: FilledButton(onPressed: () => context.go('/'), child: const Text('Go home')),
        ),
      );
}
