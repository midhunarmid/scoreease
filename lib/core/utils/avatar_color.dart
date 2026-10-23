import 'package:flutter/material.dart';

const List<Color> _avatarColors = [
  Color(0xFF1E88E5), // blue 600
  Color(0xFF8E24AA), // purple 600
  Color(0xFFFB8C00), // orange 600
  Color(0xFF00897B), // teal 600
  Color(0xFFD81B60), // pink 600
  Color(0xFF3949AB), // indigo 600
  Color(0xFF43A047), // green 600
  Color(0xFFFFA000), // amber 700
];

/// A stable colour for a player's avatar, so the same name always gets the
/// same colour on every screen.
Color avatarColorFor(String name) {
  int hash = 0;
  for (int i = 0; i < name.length; i++) {
    hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return _avatarColors[hash.abs() % _avatarColors.length];
}

String avatarInitial(String name) => name.isNotEmpty ? name[0].toUpperCase() : "?";
