import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// A cloud error with a message fit for the user.
class CloudException implements Exception {
  final String title;
  final String message;
  const CloudException(this.title, this.message);

  @override
  String toString() => '$title: $message';

  static const accessDenied = CloudException('Access denied', 'You need the password to do that.');
  static const notFound = CloudException('Not found', 'No live game with that code. Check the code and try again.');
  static const offline = CloudException('Can\'t reach the server', 'Check your internet connection and try again.');
}

bool isPermissionDenied(Object e) {
  if (e is FirebaseException && e.code.contains('permission-denied')) return true;
  return e.toString().toLowerCase().contains('permission');
}

/// Firebase is only started when a feature needs it (sharing, joining,
/// opening an old board), so local games work offline and start fast.
/// Only free Spark-plan services are used: Realtime Database, anonymous
/// Auth and Hosting.
class Cloud {
  static Future<void>? _ready;
  static bool _started = false;

  static Future<void> ensureReady() {
    return _ready ??= _init().catchError((Object e) {
      _ready = null;
      if (e is CloudException) throw e;
      throw CloudException.offline;
    });
  }

  static Future<void> _init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    }
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    _started = true;
  }

  static FirebaseDatabase get db => FirebaseDatabase.instance;

  /// Null until Firebase has started, so local games never touch it.
  static String? get uid => _started ? FirebaseAuth.instance.currentUser?.uid : null;
}
