import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityHelper {
  /// Hashes a plain-text password using SHA-256.
  /// Returns the hashed string in lowercase hex format.
  static String hashPassword(String plainText) {
    if (plainText.isEmpty) return "";
    var bytes = utf8.encode(plainText); // data being hashed
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
