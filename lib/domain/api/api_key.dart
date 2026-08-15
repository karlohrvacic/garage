import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Keys for the household's read-only API.
///
/// The key is generated on the device, shown to the user once, and stored only
/// as a hash — the same shape as any other credential. A household that loses
/// a key issues a new one rather than recovering the old.
abstract final class ApiKeys {
  static const _prefix = 'grg_';
  static const _length = 32;
  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';

  static final _random = Random.secure();

  /// A fresh key. The prefix makes it recognisable in a config file or a log,
  /// and the alphabet is what survives a URL, a header, and a shell unquoted.
  static String generate() {
    final characters = List.generate(
      _length,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    );
    return '$_prefix${characters.join()}';
  }

  /// What the database stores. SHA-256 is enough here: the key is 190 bits of
  /// randomness, so there is no dictionary to attack, and a verification has
  /// to stay fast enough to run on every API request.
  static String hash(String key) => sha256.convert(utf8.encode(key)).toString();

  /// The tail of a key, for telling two keys apart in a list without showing
  /// either of them.
  static String preview(String key) {
    final tail = key.length <= 4 ? key : key.substring(key.length - 4);
    return '…$tail';
  }
}
