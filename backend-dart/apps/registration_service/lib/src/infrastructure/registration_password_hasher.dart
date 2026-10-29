import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:hashlib/hashlib.dart';

import '../application/registration_application.dart';

class Argon2RegistrationHasher implements RegistrationPasswordHasher {
  @override
  Future<String> hash(String password) async =>
      Isolate.run(() => _hash(password));
}

String _hash(String password) {
  final rand = Random.secure();
  final salt = List<int>.generate(16, (_) => rand.nextInt(256));
  return Argon2(
    type: Argon2Type.argon2id,
    version: Argon2Version.v13,
    memorySizeKB: 19456,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
    salt: salt,
  ).encode(utf8.encode(password));
}
