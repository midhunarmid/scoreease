# ScoreEase 2.0 architecture

ScoreEase is a lightweight score tracker for Android, iOS and the web, built with Flutter. Games are stored on the device. A game touches the cloud only when its owner shares it live. Everything runs on the free Firebase **Spark** plan: Realtime Database, anonymous Auth and Hosting. There are no Cloud Functions, Firestore or Storage.

## Layers

```
lib/
  main.dart            starts Hive and DI, waits for fonts, runs the app
  app/                 MaterialApp, go_router routes, adaptive shell, get_it setup, version story
  design/              tokens, Material 3 theme (+ ScoreColors extension), breakpoints, shared widgets
  engine/              pure Dart, no Flutter: models, scoring engines, templates
  data/local/          Hive-backed LocalStore (games, events, players, backup) and SettingsStore
  data/cloud/          Firebase bootstrap, board passwords (AccessRemote), live boards, 1.x boards
  features/            home, new_game, play (cubit, mode views, TV), live viewer, share,
                       history, players (stats), settings
```

### Engine (event-sourced)

- A `Game` holds the setup: mode, template, settings and participants. It never stores scores.
- Every action is a `ScoreEvent` (`add`, `round`, `point`, `ball`, `undo`, `redo`, `end`...). Event ids use the Firebase push-id format, so events from several devices merge in time order.
- `GameEngine.compute(game, events)` drops undone events, then replays the rest through the mode's `ScoringEngine`. The result is a `GameSnapshot` with the state, standings, winners, result text and whether undo/redo are available.
- There are four engines: `CounterEngine` (with an optional match clock), `RoundsEngine`, `SetsEngine` and `CricketEngine`. `templates.dart` defines presets such as table tennis, badminton, rummy and cricket on top of them.
- Undo and redo are themselves events. They work the same way locally and between devices.

### State

`PlayCubit` (flutter_bloc) runs one game. It backs three screens: the scoring screen, the live viewer and TV mode.

- **Local game:** events load from Hive, and each new event is appended and saved.
- **Shared by this device:** the same as a local game, but events are also written to `boards/{code}/events`. The cubit listens to the cloud copy and mirrors it locally.
- **Joined from a link:** read or write access is checked first, with a password gate if needed. The cubit then streams the board.

The other screens read `LocalStore` directly and rebuild from Hive `watch()` streams.

### Layout

Breakpoints follow Material 3 window classes:

- **Compact (< 600):** bottom navigation bar; scoring is full screen.
- **Medium (600–1024):** navigation rail.
- **Expanded (≥ 1024):** extended rail. The scoring screen gets a side panel with standings and history.

Two-sided games split the screen in half, side by side in landscape and stacked in portrait. There is no pixel-scaling package: sizes come from the tokens in `design/tokens.dart`, and numbers use tabular figures.

## Cloud model (Realtime Database)

| Path | Contents | Who can read | Who can write |
|---|---|---|---|
| `boardMeta/{code}` | `ownerId`, `readProtected`, `writeProtected`, `ownerProtected` | anyone | creator (on create), then owner |
| `secrets/{code}/{read\|write\|owner}` | SHA-256 hashes | nobody | owner |
| `grants/{code}/{uid}/{level}` | hash the user entered; valid only if it equals the secret | that user | that user |
| `boards/{code}/meta` | title, mode, template, settings, participants | read level | owner |
| `boards/{code}/events/{pushId}` | `{t, d, ts, by}` | read level | write level; append only, `by` must equal `auth.uid` |
| `scoreboards/{id}` | 1.x boards: read-only in the app, can be copied into a local game | read level | unchanged 1.x rules |

- Codes are 6 characters with no confusable letters, and they share the namespace with 1.x board ids. A taken code is rejected by the `boardMeta` create rule, and the app retries with a new one.
- The rules cap sizes: participants `p0`–`p49`, and string lengths on every field.
- Viewers listen to `boards/{code}`. The SDK sends only what changed, so each point costs a few bytes.
- Stopping sharing deletes the board, its meta and its secrets. The local copy stays.

## Data on the device

Hive CE boxes hold JSON strings, so there are no type adapters or code generation:

- `games`: game JSON keyed by id.
- `events`: one map of events per game id.
- `players`: remembered names, colours and when each was last used.
- `settings`: theme, haptics, keep-awake and the board ids this device unlocked.

Backup export and import is a single JSON file. CSV export and result-card images go out through the share sheet.

## Testing and CI

- `flutter test`: engine unit tests (`test/engine`), `PlayCubit` persistence tests and adaptive-layout widget tests (`test/widget`).
- `test/database_rules`: rules tests against the RTDB emulator, covering both the 1.x roots and `boards/`. Run them with `npm ci && npm test`; they need Java.
- `.github/workflows/ci.yml` runs analyze, the tests and the rules tests on PRs and branches.
- `firebase-hosting-merge.yml` runs analyze and tests, builds the web app, and deploys Hosting plus the database rules on merge to `master`.
