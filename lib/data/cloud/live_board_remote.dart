import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

import '../../engine/engine.dart';
import 'access_remote.dart';
import 'cloud.dart';

/// A shared game as it is in the cloud.
class LiveBoard {
  final String code;
  final Game game;
  final List<ScoreEvent> events;
  final AccessMeta access;

  const LiveBoard({required this.code, required this.game, required this.events, required this.access});

  bool get isMine => access.ownerId != null && access.ownerId == Cloud.uid;
}

/// Shared games live under `boards/{code}`:
///
/// * `meta`    title, mode, settings, participants (owner writes)
/// * `events/{pushId}`  the event log; scorers append, nobody edits
///
/// Viewers listen to the board; the SDK only sends what changed, so a live
/// game costs a few bytes per point on the free plan.
class LiveBoardRemote {
  static const root = 'boards';
  static const _alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';

  final AccessRemote access;
  LiveBoardRemote(this.access);

  FirebaseDatabase get _db => Cloud.db;

  static String liveGameId(String code) => 'live_$code';

  static String _newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  /// Uploads a local game and returns its share code.
  Future<String> publish(Game game, List<ScoreEvent> events, {String readPassword = '', String writePassword = ''}) async {
    await Cloud.ensureReady();
    final uid = Cloud.uid;
    if (uid == null) throw CloudException.offline;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _newCode();
      final updates = <String, dynamic>{
        '${AccessRemote.meta}/$code': AccessMeta(
          ownerId: uid,
          readProtected: readPassword.isNotEmpty,
          writeProtected: writePassword.isNotEmpty,
        ).toMap(),
        '$root/$code/meta': game.toMetaJson(),
        for (final e in events) '$root/$code/events/${e.id}': ScoreEvent(id: e.id, type: e.type, data: e.data, ts: e.ts, by: uid).toJson(),
      };
      AccessRemote.addSecretUpdates(updates, code,
          read: readPassword.isEmpty ? null : readPassword, write: writePassword.isEmpty ? null : writePassword);
      try {
        await _db.ref().update(updates);
        return code;
      } catch (e) {
        // A taken code is rejected by the rules; try another one.
        if (!isPermissionDenied(e)) rethrow;
      }
    }
    throw const CloudException('Couldn\'t share', 'Please try again in a moment.');
  }

  /// Owner only: updates title, players or settings.
  Future<void> updateMeta(String code, Game game) => _guard(() => _db.ref('$root/$code/meta').set(game.toMetaJson()));

  /// Owner only: changes passwords. `null` keeps, empty string removes.
  Future<void> setPasswords(String code, {String? read, String? write}) async {
    final updates = <String, dynamic>{
      if (read != null) '${AccessRemote.meta}/$code/readProtected': read.isNotEmpty,
      if (write != null) '${AccessRemote.meta}/$code/writeProtected': write.isNotEmpty,
    };
    AccessRemote.addSecretUpdates(updates, code, read: read, write: write);
    await _guard(() => _db.ref().update(updates));
  }

  /// Owner only: removes the game from the cloud. The local copy stays.
  Future<void> unpublish(String code) => _guard(() => _db.ref().update({
        '$root/$code': null,
        '${AccessRemote.secrets}/$code': null,
        '${AccessRemote.meta}/$code': null,
      }));

  Future<void> addEvent(String code, ScoreEvent event) async {
    final uid = Cloud.uid ?? 'local';
    final e = ScoreEvent(id: event.id, type: event.type, data: event.data, ts: event.ts, by: uid);
    await _guard(() => _db.ref('$root/$code/events/${e.id}').set(e.toJson()));
  }

  /// Streams the board. Errors with [CloudException.accessDenied] when the
  /// user lacks read access and [CloudException.notFound] when it's gone.
  Stream<LiveBoard> watch(String code, AccessMeta accessMeta) {
    return _db.ref('$root/$code').onValue.handleError((Object e) {
      if (isPermissionDenied(e)) throw CloudException.accessDenied;
      throw e;
    }).map((event) {
      final value = event.snapshot.value;
      if (value is! Map || value['meta'] is! Map) throw CloudException.notFound;
      final game = Game.fromJson(value['meta'] as Map, id: liveGameId(code)).copyWith(
        shareCode: code,
        isOwner: accessMeta.ownerId == Cloud.uid,
      );
      final rawEvents = value['events'];
      final events = <ScoreEvent>[
        if (rawEvents is Map)
          for (final entry in rawEvents.entries)
            if (entry.value is Map) ScoreEvent.fromJson(entry.key.toString(), entry.value as Map),
      ]..sort((a, b) => a.id.compareTo(b.id));
      return LiveBoard(code: code, game: game, events: events, access: accessMeta);
    });
  }

  Future<void> _guard(Future<void> Function() write) async {
    await Cloud.ensureReady();
    try {
      await write();
    } catch (e) {
      if (isPermissionDenied(e)) throw CloudException.accessDenied;
      rethrow;
    }
  }
}
