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
    "5": ScoreEaseVersionStory(
      versionSemantic: "1.4.0",
      versionName: "Messi",
      buildNumber: "5",
      buildDate: "TBD",
      tagline: "Unplayable team dynamics.",
      features: [
        "Team Games Support - A massive architectural update to support Team vs Team formats (individual scores + total team scores).",
      ],
    ),
    "4": ScoreEaseVersionStory(
      versionSemantic: "1.3.0",
      versionName: "Rohit",
      buildNumber: "4",
      buildDate: "23-January-2026",
      tagline: "Unleashing the hitman's power.",
      features: [
        "Scoreboard Editor - Full control to add/delete players, edit names, and manage access post-creation.",
        "Owner Security - Enhanced security by requiring an owner password to modify scoreboard details.",
        "Silky Smooth UI - Adding even more delightful micro-animations when updating scores and UI elements.",
      ],
    ),
    "3": ScoreEaseVersionStory(
      versionSemantic: "1.2.0",
      versionName: "Kohli",
      buildNumber: "3",
      buildDate: "17-December-2025",
      tagline: "Chasing perfection in real-time.",
      features: [
        "Version History Timeline - A beautiful, interactive timeline to track ScoreEase's journey and upcoming roadmap.",
        "Auth Persistence - Never type your password twice! We now remember your unlocked scoreboards securely on your device.",
        "Fortified Security - Enhanced password protection with state-of-the-art SHA-256 encryption.",
        "Settings Overhaul - A completely redesigned settings experience featuring our signature premium look.",
      ],
    ),
    "2": ScoreEaseVersionStory(
      versionSemantic: "1.1.0",
      versionName: "Dhoni",
      buildNumber: "2",
      buildDate: "22-September-2025",
      tagline: "Finishing it off in style. Modern, fast, and smooth.",
      features: [
        "Premium Design - A complete visual overhaul featuring a sleek, glassmorphic interface.",
        "Dynamic Themes - Seamlessly toggle between Light, Dark, and System Default aesthetics.",
        "Fluid Animations - Satisfying, responsive micro-animations with every tap and swipe.",
        "Enhanced Security - Keep your scoreboards safe with newly integrated access protection.",
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
