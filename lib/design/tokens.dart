import 'package:flutter/material.dart';

/// Spacing scale. Use these instead of ad-hoc numbers.
class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

const Color brandSeed = Color(0xFF10B981);

/// Max width for forms and reading content on large screens.
const double contentMaxWidth = 720;

const Duration motionFast = Duration(milliseconds: 150);
const Duration motionMedium = Duration(milliseconds: 250);

/// Colours for players and teams. Index stored in [Participant.color].
const List<Color> playerPalette = [
  Color(0xFF1E88E5),
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFFD81B60),
  Color(0xFF3949AB),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
];

Color playerColor(int index) => playerPalette[index.abs() % playerPalette.length];
