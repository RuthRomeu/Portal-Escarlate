import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:hashlib/hashlib.dart';

abstract interface class PasswordService {
  Future<String> hash(String password);
  Future<bool> verify(String password, String encodedHash);
}

/// Hashes PHC $argon2id$ compatíveis com a configuração do Node.js.
/// Isolates evitam bloquear o processamento de outras requisições HTTP.
class Argon2Passwords implements PasswordService {
  @override
  Future<String> hash(String password) =>
      Isolate.run(() => _hashPassword(password));

  @override
  Future<bool> verify(String password, String encodedHash) async {
    if (!encodedHash.startsWith(r'$argon2id$v=19$')) return false;
    try {
      return await Isolate.run(
          () => argon2Verify(encodedHash, utf8.encode(password)));
    } on Exception {
      return false;
    }
  }
}

String _hashPassword(String password) {
  final random = Random.secure();
  final salt = List<int>.generate(16, (_) => random.nextInt(256));
  final encoder = Argon2(
    type: Argon2Type.argon2id,
    version: Argon2Version.v13,
    memorySizeKB: 19456,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
    salt: salt,
  );
  return encoder.encode(utf8.encode(password));
}
