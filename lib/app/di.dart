import 'package:get_it/get_it.dart';

import '../data/cloud/access_remote.dart';
import '../data/cloud/legacy_board_remote.dart';
import '../data/cloud/live_board_remote.dart';
import '../data/local/local_store.dart';
import '../data/local/settings_store.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  final store = LocalStore();
  await store.init();
  final access = AccessRemote();
  getIt
    ..registerSingleton<LocalStore>(store)
    ..registerSingleton<SettingsStore>(SettingsStore(store.settingsBox))
    ..registerSingleton<AccessRemote>(access)
    ..registerSingleton<LiveBoardRemote>(LiveBoardRemote(access))
    ..registerSingleton<LegacyBoardRemote>(LegacyBoardRemote(access));
}
