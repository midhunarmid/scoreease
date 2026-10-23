import 'package:flutter/material.dart';

/// Material 3 window size classes.
enum WindowSize { compact, medium, expanded }

class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  static WindowSize of(double width) => width >= expanded
      ? WindowSize.expanded
      : width >= medium
          ? WindowSize.medium
          : WindowSize.compact;
}

extension ResponsiveX on BuildContext {
  WindowSize get windowSize => Breakpoints.of(MediaQuery.sizeOf(this).width);
  bool get isCompact => windowSize == WindowSize.compact;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// Page padding that grows with the window.
  double get gutter => switch (windowSize) { WindowSize.compact => 16, WindowSize.medium => 24, WindowSize.expanded => 32 };
}

/// Centres [child] and limits its width, for forms and lists on big screens.
class MaxWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MaxWidth({super.key, this.maxWidth = 720, this.padding = EdgeInsets.zero, required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}
