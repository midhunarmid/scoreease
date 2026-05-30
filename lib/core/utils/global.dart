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
}
