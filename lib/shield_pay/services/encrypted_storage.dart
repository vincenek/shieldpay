import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

class EncryptedStorageService {
  // In-memory derived key for the session.
  static enc.Key? _key;

  static void setPassphrase(String passphrase) {
    // Deprecated: use PBKDF2 variants instead. Keep a simple shim for
    // compatibility but prefer `createAndSetPassphrase` or
    // `setPassphraseWithSalt` which derive keys using PBKDF2.
    final bytes = pc.SHA256Digest().process(Uint8List.fromList(utf8.encode(passphrase)));
    _key = enc.Key(Uint8List.fromList(bytes));
  }

  static void clearKey() {
    _key = null;
  }

  // Indicates whether a derived key is present in memory for this session.
  static bool get isKeySet => _key != null;
  

  static String encryptJson(String json) {
    if (_key == null) throw StateError('Encryption key not set');
    final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
    final ivBytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final ct = encrypter.encrypt(json, iv: iv);
    final payload = base64Url.encode(iv.bytes) + ':' + ct.base64;
    return payload;
  }

  static String decryptJson(String payload) {
    if (_key == null) throw StateError('Encryption key not set');
    final parts = payload.split(':');
    if (parts.length != 2) throw FormatException('Invalid payload');
    final ivb = base64Url.decode(parts[0]);
    final ct = parts[1];
    final encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.gcm));
    final iv = enc.IV(Uint8List.fromList(ivb));
    final dec = encrypter.decrypt64(ct, iv: iv);
    return dec;
  }

  // Strong key derivation using PBKDF2 (HMAC-SHA256).
  // Returns the generated salt (base64url) which should be persisted
  // alongside the encrypted blob (salt is non-secret).
  static String createAndSetPassphrase(String passphrase,
      {int iterations = 100000, int saltLength = 16}) {
    final salt = List<int>.generate(saltLength, (_) => Random.secure().nextInt(256));
    _key = _deriveKey(passphrase, Uint8List.fromList(salt), iterations);
    return base64Url.encode(salt);
  }

  // Use an existing salt (base64url) to derive and set the key.
  static void setPassphraseWithSalt(String passphrase, String saltBase64,
      {int iterations = 100000}) {
    final salt = base64Url.decode(saltBase64);
    _key = _deriveKey(passphrase, Uint8List.fromList(salt), iterations);
  }

  static enc.Key _deriveKey(String passphrase, Uint8List salt, int iterations) {
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    final params = pc.Pbkdf2Parameters(salt, iterations, 32);
    derivator.init(params);
    final key = derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
    return enc.Key(Uint8List.fromList(key));
  }
}
