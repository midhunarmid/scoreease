import 'package:shared_preferences/shared_preferences.dart';

class GlobalValues {
  static Future<void> setLastUpdatedTime(
      {required String collection, required int lastUpdateTime}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(collection, lastUpdateTime);
  }

  static Future<int> getLastUpdatedTime({required String collection}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(collection) ?? 0;
  }

  static Future<void> unlockScoreboardAccess({required String scoreboardId, required String type}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('access_${type}_$scoreboardId', true);
  }

  static Future<bool> hasScoreboardAccess({required String scoreboardId, required String type}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('access_${type}_$scoreboardId') ?? false;
  }

  static Future<void> clearAllScoreboardAccesses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('access_read_') || key.startsWith('access_write_')) {
        await prefs.remove(key);
      }
    }
  }
}
