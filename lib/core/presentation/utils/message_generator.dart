class MessageGenerator {
  static const Map<String, Map<String, String>> _messageMap = {
    "en": {
      "un-expected-error": "Some un expected error happened!",
      "un-expected-error-message": "Some un expected error happened!",
      "landing-welcome": "Welcome! Let’s set up your scoreboard. Please enter a name to get started.",
      "landing-visit-site-guide":
          "To get started with this open-source Scoreboard app, visit https://github.com/midhunarmid/scoreease for setup instructions and full documentation.",
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
