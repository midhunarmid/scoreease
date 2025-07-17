class ScoreEaseVersionStory {
  final String versionSemantic;
  final String versionName;
  final String buildNumber;
  final String buildDate;
  final String tagline;
  final List<String> features;

  ScoreEaseVersionStory({
    required this.versionSemantic,
    required this.versionName,
    required this.buildNumber,
    required this.buildDate,
    required this.tagline,
    required this.features,
  });

  String get versionDisplay => versionName;

  static Map<String, ScoreEaseVersionStory> versionStoryMap = {
    "1": ScoreEaseVersionStory(
      versionSemantic: "1.0.0",
      versionName: "Sachin",
      buildNumber: "1",
      buildDate: "19-July-2025",
      tagline: "Built to last. Just like the master.",
      features: [
        "Game On - Launched with core scoreboard functionality to track the action.",
        "Team Ready - Now supports scoring for multiple players — more rivals, more fun.",
        "Clear View - Simple, focused UI that puts scores front and center.",
        "Play Anywhere - Optimized for both web and mobile — take the game wherever you go!",
      ],
    ),
  };
}
