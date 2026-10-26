import 'models.dart';

/// A ready-made setup for a game people play. Settings can still be tweaked
/// before starting.
class GameTemplate {
  final String id;
  final String name;
  final String blurb;
  final GameMode mode;
  final Map<String, dynamic> settings;

  /// Exactly two sides (sets and cricket).
  final bool twoSides;
  final bool teamsByDefault;
  final String emoji;

  const GameTemplate({
    required this.id,
    required this.name,
    required this.blurb,
    required this.mode,
    required this.emoji,
    this.settings = const {},
    this.twoSides = false,
    this.teamsByDefault = false,
  });
}

class Templates {
  static const counter = GameTemplate(
    id: 'counter',
    name: 'Counter',
    blurb: 'Tap +/- for any game',
    mode: GameMode.counter,
    emoji: '➕',
    settings: {'steps': '1'},
  );

  static const all = <GameTemplate>[
    counter,
    GameTemplate(
      id: 'rounds',
      name: 'Rounds',
      blurb: 'Score sheet with round totals',
      mode: GameMode.rounds,
      emoji: '📝',
    ),
    GameTemplate(
      id: 'tabletennis',
      name: 'Table tennis',
      blurb: '11 points, best of 5',
      mode: GameMode.sets,
      emoji: '🏓',
      twoSides: true,
      settings: {'points': 11, 'winBy': 2, 'sets': 3, 'serveEvery': 2},
    ),
    GameTemplate(
      id: 'badminton',
      name: 'Badminton',
      blurb: '21 points, best of 3',
      mode: GameMode.sets,
      emoji: '🏸',
      twoSides: true,
      settings: {'points': 21, 'winBy': 2, 'cap': 30, 'sets': 2, 'serveEvery': 0},
    ),
    GameTemplate(
      id: 'volleyball',
      name: 'Volleyball',
      blurb: '25 points, best of 5',
      mode: GameMode.sets,
      emoji: '🏐',
      twoSides: true,
      teamsByDefault: true,
      settings: {'points': 25, 'winBy': 2, 'sets': 3, 'decidingPoints': 15, 'serveEvery': 0},
    ),
    GameTemplate(
      id: 'pickleball',
      name: 'Pickleball',
      blurb: '11 points, best of 3',
      mode: GameMode.sets,
      emoji: '🥒',
      twoSides: true,
      settings: {'points': 11, 'winBy': 2, 'sets': 2, 'serveEvery': 0},
    ),
    GameTemplate(
      id: 'cricket',
      name: 'Cricket',
      blurb: 'Runs, wickets, overs',
      mode: GameMode.cricket,
      emoji: '🏏',
      twoSides: true,
      teamsByDefault: true,
      settings: {'overs': 6, 'wickets': 10, 'battingFirst': 0, 'wideRuns': 1, 'noBallRuns': 1},
    ),
    GameTemplate(
      id: 'rummy',
      name: 'Rummy',
      blurb: 'Lowest wins, out at 201',
      mode: GameMode.rounds,
      emoji: '🃏',
      settings: {'lowWins': true, 'eliminateAt': 201},
    ),
    GameTemplate(
      id: 'uno',
      name: 'UNO',
      blurb: 'First to 500',
      mode: GameMode.rounds,
      emoji: '🎴',
      settings: {'target': 500},
    ),
    GameTemplate(
      id: 'golf',
      name: 'Golf',
      blurb: '18 holes, lowest wins',
      mode: GameMode.rounds,
      emoji: '⛳',
      settings: {'lowWins': true, 'maxRounds': 18},
    ),
    GameTemplate(
      id: 'carrom',
      name: 'Carrom',
      blurb: 'First to 25',
      mode: GameMode.counter,
      emoji: '🎯',
      settings: {'target': 25, 'steps': '1,3'},
    ),
    GameTemplate(
      id: 'basketball',
      name: 'Basketball',
      blurb: '1-2-3 pointers, 4 quarters',
      mode: GameMode.counter,
      emoji: '🏀',
      teamsByDefault: true,
      settings: {'steps': '1,2,3', 'periods': 4, 'periodMinutes': 10},
    ),
    GameTemplate(
      id: 'football',
      name: 'Football',
      blurb: 'Goals with a match clock',
      mode: GameMode.counter,
      emoji: '⚽',
      teamsByDefault: true,
      settings: {'steps': '1', 'periods': 2, 'periodMinutes': 45},
    ),
    GameTemplate(
      id: 'musicalchairs',
      name: 'Musical chairs',
      blurb: 'Tap who\'s out, last one wins',
      mode: GameMode.placements,
      emoji: '🪑',
      settings: {'order': 'out', 'placePoints': '3,2,1'},
    ),
    GameTemplate(
      id: 'race',
      name: 'Race',
      blurb: 'Tap players as they finish',
      mode: GameMode.placements,
      emoji: '🏃',
      settings: {'order': 'finish', 'placePoints': '3,2,1'},
    ),
  ];

  static GameTemplate byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => counter);
}
