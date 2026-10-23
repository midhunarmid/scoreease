import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';

import 'cloud.dart';

enum AccessLevel { read, write, owner }

/// Public flags of a board: who owns it and which levels need a password.
class AccessMeta {
  final String? ownerId;
  final bool readProtected;
  final bool writeProtected;
  final bool ownerProtected;

  const AccessMeta({this.ownerId, this.readProtected = false, this.writeProtected = false, this.ownerProtected = false});

  factory AccessMeta.fromMap(Map map) => AccessMeta(
        ownerId: map['ownerId']?.toString(),
        readProtected: map['readProtected'] == true,
        writeProtected: map['writeProtected'] == true,
        ownerProtected: map['ownerProtected'] == true,
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'readProtected': readProtected,
        'writeProtected': writeProtected,
        'ownerProtected': ownerProtected,
      };

  bool needsPassword(AccessLevel level) => switch (level) {
        AccessLevel.read => readProtected,
        AccessLevel.write => writeProtected,
        AccessLevel.owner => true,
      };
}

String hashPassword(String plain) => plain.isEmpty ? '' : sha256.convert(utf8.encode(plain)).toString();

/// Board passwords, enforced by database.rules.json:
///
/// * `boardMeta/{id}`  public flags: owner uid and which levels are protected
/// * `secrets/{id}`    password hashes, never readable by any client
/// * `grants/{id}/{uid}/{level}`  a hash the user entered; the rules only accept
///   it when it matches the secret, which then unlocks that level for the user
class AccessRemote {
  static const meta = 'boardMeta';
  static const secrets = 'secrets';
  static const grants = 'grants';

  FirebaseDatabase get _db => Cloud.db;

  Future<AccessMeta?> getMeta(String id) async {
    await Cloud.ensureReady();
    final snapshot = await _db.ref(meta).child(id).get();
    if (snapshot.value is! Map) return null;
    return AccessMeta.fromMap(snapshot.value as Map);
  }

  /// Whether the signed-in user currently has [level] access to board [id].
  /// Saved grants are re-checked against the server, so a changed password
  /// locks people out again.
  Future<bool> hasAccess(String id, AccessLevel level, {AccessMeta? known}) async {
    final m = known ?? await getMeta(id);
    if (m == null) throw CloudException.notFound;
    final uid = Cloud.uid;
    if (uid == null) return false;
    if (m.ownerId == uid) return true;
    if (await _hasValidGrant(id, AccessLevel.owner)) return true;
    if (level == AccessLevel.owner) return false;

    // The write password also lets you view, but an open write level still
    // respects the read password. Mirrors database.rules.json.
    if (await _hasValidGrant(id, AccessLevel.write)) return true;
    if (level == AccessLevel.write && m.writeProtected) return false;
    return !m.readProtected || await _hasValidGrant(id, AccessLevel.read);
  }

  /// Stores the entered password hash as a grant. The security rules reject it
  /// unless it matches the board's secret, so a rejection means wrong password.
  Future<bool> unlock(String id, AccessLevel level, String password) async {
    await Cloud.ensureReady();
    final hash = hashPassword(password);
    if (Cloud.uid == null || hash.isEmpty) return false;
    try {
      await _grantRef(id, level).set(hash);
      return true;
    } catch (e) {
      if (isPermissionDenied(e)) return false;
      rethrow;
    }
  }

  /// Removes this user's saved grants for the given boards.
  Future<void> revokeGrants(Iterable<String> ids) async {
    await Cloud.ensureReady();
    final uid = Cloud.uid;
    if (uid == null) return;
    for (final id in ids) {
      await _db.ref(grants).child(id).child(uid).remove();
    }
  }

  /// Adds the password hash updates for a multi-path write. `null` leaves a
  /// level unchanged, an empty string removes its password.
  static void addSecretUpdates(Map<String, dynamic> updates, String id, {String? read, String? write, String? owner}) {
    void add(AccessLevel level, String? plain) {
      if (plain == null) return;
      updates['$secrets/$id/${level.name}'] = plain.isEmpty ? null : hashPassword(plain);
    }

    add(AccessLevel.read, read);
    add(AccessLevel.write, write);
    add(AccessLevel.owner, owner);
  }

  DatabaseReference _grantRef(String id, AccessLevel level) => _db.ref(grants).child(id).child(Cloud.uid!).child(level.name);

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
}
