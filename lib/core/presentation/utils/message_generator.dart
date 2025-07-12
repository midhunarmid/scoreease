class MessageGenerator {
  static const Map<String, Map<String, String>> _messageMap = {
    "en": {
      "un-expected-error": "Some un expected error happened!",
      "un-expected-error-message": "Some un expected error happened!",
      "landing-welcome": "Welcome! Let’s set up your scoreboard. Please enter a name to get started.",
      "landing-visit-site-guide":
          "To get started with this open-source Scoreboard app, visit https://github.com/midhunarmid/scoreease for setup instructions and full documentation.",
      "scoreboard-welcome": "Game on! Name your scoreboard and rally your players!",
      "scoreboard-setup-basic-title": "① Name It. Own It. Play On.",
      "scoreboard-setup-players-title": "② Line Up Your Squad!",
      "scoreboard-setup-access-title": "③ Who Can Watch? Who Can Score?",
      "scoreboard-name-empty": "Oops! No Name, No Game!",
      "scoreboard-name-empty-message": "Please enter a scoreboard name to get the game rolling. Even legends need a title!",
      "scoreboard-name-too-short": "Too Short to Score!",
      "scoreboard-name-too-short-message": "Your scoreboard name should be at least 3 characters long. Try something bold or fun!",
      "scoreboard-author-empty": "Who’s Keeping Score?",
      "scoreboard-author-empty-message": "Please enter your name or team name to take credit for this scoreboard!",
      "scoreboard-author-too-short": "Name’s Too Short!",
      "scoreboard-author-too-short-message": "Your name should be at least 3 characters long. Make it memorable!"
    }
  };

  static const Map<String, Map<String, String>> _labelMap = {
    "en": {
      "OK": "OK",
    }
  };

  static String getMessage(String message) {
    return (_messageMap[getLanguage()] ?? {})[message] ?? message;
  }

  static String getLabel(String label) {
    return (_labelMap[getLanguage()] ?? {})[label] ?? label;
  }

  static String getLanguage() {
    // Implement multi language support here
    return "en";
  }
}
