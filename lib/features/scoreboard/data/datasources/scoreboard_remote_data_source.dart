import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:scoreease/core/utils/firebase_collections.dart';
import 'package:scoreease/features/scoreboard/data/models/access_model.dart';
import 'package:scoreease/features/scoreboard/data/models/scoreboard_model.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/core/utils/my_app_exception.dart';
import 'package:scoreease/main.dart';

/// Talks to the Realtime Database. Data is split across four roots so that the
/// security rules (database.rules.json) can enforce board passwords:
///
/// * `boardMeta/{id}`  public flags: owner uid and which levels are protected
/// * `secrets/{id}`    password hashes, never readable by any client
/// * `grants/{id}/{uid}/{level}`  a hash the user entered; the rules only accept
///   it when it matches the secret, which then unlocks that level for the user
/// * `scoreboards/{id}` the board itself, readable/writable per the levels above
class ScoreboardRemoteDataSource {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  static const String _meta = 'boardMeta';
  static const String _secrets = 'secrets';
  static const String _grants = 'grants';

  String get _boards => FireStoreCollection.scoreboards.name;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static bool isPermissionDenied(Object e) {
    if (e is FirebaseException && e.code.contains('permission-denied')) return true;
    return e.toString().toLowerCase().contains('permission');
  }

  static const MyAppException accessDenied = MyAppException(
    title: "Access Denied",
    message: "You don't have access to this scoreboard. Please enter the password again.",
  );

  Future<AccessMetaModel?> getAccessMeta(String id) async {
    if (id.isEmpty) return null;
    DataSnapshot snapshot = await _db.ref(_meta).child(id).get();
    if (snapshot.value == null) return null;
    return AccessMetaModel.fromMap(Map<String, dynamic>.from(snapshot.value as Map));
  }

  Future<ScoreboardModel?> getScoreboard({required String id}) async {
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    AccessMetaModel? meta = await getAccessMeta(id);
    if (meta == null) {
      MyApp.debugPrint("Server items []");
      return null;
    }

    DataSnapshot snapshot;
    try {
      snapshot = await _db.ref(_boards).child(id).get();
    } catch (e) {
      if (isPermissionDenied(e)) throw accessDenied;
      rethrow;
    }

    if (snapshot.value != null) {
      ScoreboardModel model =
          ScoreboardModel.fromMap(Map<String, dynamic>.from(snapshot.value as Map)).copyWith(access: meta);
      MyApp.debugPrint("Server items [$model]");
      return model;
    }

    MyApp.debugPrint("Server items []");
    return null;
  }

  /// Creates the board, its public flags and its password hashes in one
  /// atomic write. Fails if the ID is already taken.
  Future<String?> createScoreboard({required ScoreboardModel scoreboardModel, required AccessModel secrets}) async {
    String id = scoreboardModel.id ?? "";
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    final meta = AccessMetaModel(
      ownerId: _uid,
      readProtected: secrets.read?.isNotEmpty ?? false,
      writeProtected: secrets.write?.isNotEmpty ?? false,
      ownerProtected: secrets.owner?.isNotEmpty ?? false,
    );

    final Map<String, dynamic> updates = {
      '$_meta/$id': meta.toMap(),
      '$_boards/$id': scoreboardModel.copyWith(ownerId: _uid).toMap(),
    };
    _addSecretUpdates(updates, id, secrets);

    try {
      await _db.ref().update(updates);
    } catch (e) {
      if (isPermissionDenied(e)) {
        throw const MyAppException(
          title: "ID Unavailable",
          message: "A scoreboard with this ID already exists. Please choose a different ID.",
        );
      }
      rethrow;
    }

    MyApp.debugPrint("Scoreboard created with id $id");
    return id;
  }

  /// Saves board details and, when given, password changes. Owner only.
  Future<String?> updateScoreboard({required ScoreboardModel scoreboardModel, AccessModel? secrets}) async {
    String id = scoreboardModel.id ?? "";
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    final Map<String, dynamic> updates = {};
    scoreboardModel.toMap().forEach((key, value) {
      if (key != 'createdAt' && key != 'ownerId') updates['$_boards/$id/$key'] = value;
    });

    if (secrets != null) {
      final current = await getAccessMeta(id) ?? const AccessMetaModel();
      bool flag(String? hash, bool old) => hash == null ? old : hash.isNotEmpty;
      updates['$_meta/$id/readProtected'] = flag(secrets.read, current.readProtected);
      updates['$_meta/$id/writeProtected'] = flag(secrets.write, current.writeProtected);
      updates['$_meta/$id/ownerProtected'] = flag(secrets.owner, current.ownerProtected);
      _addSecretUpdates(updates, id, secrets);
    }

    await _guard(() => _db.ref().update(updates));
    MyApp.debugPrint("Scoreboard saved with id $id");
    return id;
  }

  /// Replaces the scores of the given players. Needs write access.
  Future<void> setPlayerScores({required String id, required Map<String, int> scores}) async {
    final Map<String, dynamic> updates = {
      for (final entry in scores.entries) '$_boards/$id/players/${entry.key}': entry.value,
      '$_boards/$id/lastUpdated': ServerValue.timestamp,
    };
    await _guard(() => _db.ref().update(updates));
  }

  /// Whether the signed-in user currently has [level] access to board [id].
  /// Saved grants are re-checked against the server, so a changed password
  /// locks people out again.
  Future<bool> hasAccess(String id, AccessLevel level) async {
    final meta = await getAccessMeta(id);
    if (meta == null) {
      throw const MyAppException(
        title: "Scoreboard Not Found",
        message: "No score board found with that ID",
      );
    }
    if (_uid == null) return false;
    if (meta.ownerId == _uid) return true;
    if (await _hasValidGrant(id, AccessLevel.owner)) return true;
    if (level == AccessLevel.owner) return false;

    // The write password also lets you view, but an open write level still
    // respects the read password. Mirrors database.rules.json.
    if (await _hasValidGrant(id, AccessLevel.write)) return true;
    if (level == AccessLevel.write && meta.writeProtected) return false;
    return !meta.readProtected || await _hasValidGrant(id, AccessLevel.read);
  }

  /// Stores the entered password hash as a grant. The security rules reject it
  /// unless it matches the board's secret, so a rejection means wrong password.
  Future<bool> unlock(String id, AccessLevel level, String hash) async {
    if (_uid == null || hash.isEmpty) return false;
    try {
      await _grantRef(id, level).set(hash);
      return true;
    } catch (e) {
      if (isPermissionDenied(e)) return false;
      rethrow;
    }
  }

  /// Removes the user's saved grants for the given boards.
  Future<void> revokeGrants(Iterable<String> ids) async {
    if (_uid == null) return;
    for (final id in ids) {
      await _db.ref(_grants).child(id).child(_uid!).remove();
    }
  }

  Stream<ScoreboardModel> listenToScoreboard(String id) {
    String collection = FireStoreCollection.scoreboards.name;
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      throw const MyAppException(
        title: "Scoreboard ID is empty",
        message: "Scoreboard ID cannot be empty. Please provide a valid ID to listen to the scoreboard.",
      );
    }

    return _db.ref(collection).child(id).onValue.handleError((Object e) {
      if (isPermissionDenied(e)) throw accessDenied;
      throw e;
    }).map((event) {
      if (event.snapshot.value == null) {
        throw const MyAppException(
          title: "Scoreboard Not Found",
          message: "The scoreboard data is empty or has been deleted.",
        );
      }
      return ScoreboardModel.fromMap(Map<String, dynamic>.from(event.snapshot.value as Map));
    });
  }

  DatabaseReference _grantRef(String id, AccessLevel level) =>
      _db.ref(_grants).child(id).child(_uid!).child(level.name);

  Future<bool> _hasValidGrant(String id, AccessLevel level) async {
    final ref = _grantRef(id, level);
    final snapshot = await ref.get();
    final value = snapshot.value;
    if (value is! String) return false;
    // Rewriting the same value makes the rules re-check it against the
    // current secret. A rejection means the password has since changed.
    try {
      await ref.set(value);
      return true;
    } catch (e) {
      if (!isPermissionDenied(e)) rethrow;
      await ref.remove();
      return false;
    }
  }

  void _addSecretUpdates(Map<String, dynamic> updates, String id, AccessModel secrets) {
    void add(AccessLevel level, String? hash) {
      if (hash == null) return;
      updates['$_secrets/$id/${level.name}'] = hash.isEmpty ? null : hash;
    }

    add(AccessLevel.read, secrets.read);
    add(AccessLevel.write, secrets.write);
    add(AccessLevel.owner, secrets.owner);
  }

  Future<void> _guard(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      if (isPermissionDenied(e)) throw accessDenied;
      rethrow;
    }
  }
}
