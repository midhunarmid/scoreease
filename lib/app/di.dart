import 'package:get_it/get_it.dart';

import '../data/cloud/access_remote.dart';
import '../data/cloud/event_board_remote.dart';
import '../data/cloud/legacy_board_remote.dart';
import '../data/cloud/live_board_remote.dart';
import '../data/local/local_store.dart';
import '../data/local/settings_store.dart';
import '../features/events/event_sharing.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  final store = LocalStore();
  await store.init();
  final access = AccessRemote();
  final boards = LiveBoardRemote(access);
  final events = EventBoardRemote();
  getIt
    ..registerSingleton<LocalStore>(store)
    ..registerSingleton<SettingsStore>(SettingsStore(store.settingsBox))
    ..registerSingleton<AccessRemote>(access)
    ..registerSingleton<LiveBoardRemote>(boards)
    ..registerSingleton<EventBoardRemote>(events)
    ..registerSingleton<EventSharing>(EventSharing(store, events, boards))
    ..registerSingleton<LegacyBoardRemote>(LegacyBoardRemote(access));
}
