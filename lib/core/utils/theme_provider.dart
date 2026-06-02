import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scoreease/core/utils/theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  static const String _themeKey = 'theme_mode';

  ThemeProvider() {
    _loadTheme();
    // Listen to system brightness changes if the user is on System mode
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (themeMode == ThemeMode.system) {
        _updateGlobalColors();
        notifyListeners();
      }
    };
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme == 'light') {
      themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      themeMode = ThemeMode.dark;
    } else {
      themeMode = ThemeMode.system;
    }
    
    _updateGlobalColors();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    _updateGlobalColors();
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  void _updateGlobalColors() {
    Brightness brightness;
    if (themeMode == ThemeMode.system) {
      brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    } else {
      brightness = themeMode == ThemeMode.light ? Brightness.light : Brightness.dark;
    }
    
    // Dynamically update the global appColors reference so that static usages across the app reflect the current mode
    appColors = brightness == Brightness.light ? AppColorsLight() : AppColorsDark();
    // Also update the global appTheme to ensure anything calling it gets the right fallback
    appTheme = brightness == Brightness.light ? getLightTheme() : getDarkTheme();
  }
}

// Global singleton instance for easy access
final themeProvider = ThemeProvider();
