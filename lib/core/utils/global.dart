import 'package:shared_preferences/shared_preferences.dart';

class GlobalValues {
  static const String _unlockedScoreboardsKey = 'unlocked_scoreboards';

  static Future<void> setLastUpdatedTime(
      {required String collection, required int lastUpdateTime}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(collection, lastUpdateTime);
  }

  static Future<int> getLastUpdatedTime({required String collection}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(collection) ?? 0;
  }

  /// Remembers that this browser holds a password grant for [scoreboardId], so
  /// it can be revoked from settings. Access itself is checked on the server.
  static Future<void> rememberUnlockedScoreboard(String scoreboardId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_unlockedScoreboardsKey) ?? [];
    if (!ids.contains(scoreboardId)) {
      await prefs.setStringList(_unlockedScoreboardsKey, [...ids, scoreboardId]);
    }
  }

  static Future<List<String>> getUnlockedScoreboards() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedScoreboardsKey) ?? [];
  }

  static Future<void> clearUnlockedScoreboards() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unlockedScoreboardsKey);
    // Flags written by versions before 1.5.0, which only checked passwords locally.
    for (String key in prefs.getKeys().toList()) {
      if (key.startsWith('access_read_') || key.startsWith('access_write_') || key.startsWith('access_owner_')) {
        await prefs.remove(key);
      }
    }
  }
}
