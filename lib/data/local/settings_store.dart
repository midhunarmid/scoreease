import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

/// App preferences, backed by a Hive box. Listen to it to rebuild on change.
class SettingsStore extends ChangeNotifier {
  final Box _box;

  SettingsStore(this._box);

  ThemeMode get themeMode => ThemeMode.values.firstWhere((m) => m.name == _box.get('themeMode'), orElse: () => ThemeMode.system);
  set themeMode(ThemeMode mode) => _put('themeMode', mode.name);

  bool get haptics => _box.get('haptics', defaultValue: true) as bool;
  set haptics(bool v) => _put('haptics', v);

  bool get keepAwake => _box.get('keepAwake', defaultValue: true) as bool;
  set keepAwake(bool v) => _put('keepAwake', v);

  /// Two-player counter games turn the top half around, for a tablet lying
  /// flat between the players.
  bool get faceToFace => _box.get('faceToFace', defaultValue: false) as bool;
  set faceToFace(bool v) => _put('faceToFace', v);

  /// Board ids this device unlocked with a password, so they can be revoked.
  List<String> get unlockedBoards => List<String>.from(_box.get('unlockedBoards', defaultValue: const <String>[]) as List);
  set unlockedBoards(List<String> ids) => _put('unlockedBoards', ids);

  void _put(String key, Object value) {
    _box.put(key, value);
    notifyListeners();
  }
}
