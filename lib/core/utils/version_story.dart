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
    "3": ScoreEaseVersionStory(
      versionSemantic: "3.0.0",
      versionName: "Kohli",
      buildNumber: "3",
      buildDate: "31-May-2026",
      tagline: "Chasing perfection in real-time.",
      features: [
        "Real-Time Speed - Migrated to Firebase Realtime Database for lightning-fast score syncing.",
        "Cost Efficiency - Optimized architecture to drastically reduce database reads and costs.",
        "Under the Hood - Refactored data layer to utilize a single-source-of-truth model.",
      ],
    ),
    "2": ScoreEaseVersionStory(
      versionSemantic: "2.0.0",
      versionName: "Dhoni",
      buildNumber: "2",
      buildDate: "30-May-2026",
      tagline: "Finishing it off in style. Modern, fast, and smooth.",
      features: [
        "Modern Revamp - A complete overhaul of the UI for a sleeker, modern look.",
        "Smooth Animations - Added micro-animations and transitions for better user experience.",
        "Performance Boost - Faster interactions and improved responsiveness.",
        "Refreshed Colors - New vibrant color themes introduced.",
      ],
    ),
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
