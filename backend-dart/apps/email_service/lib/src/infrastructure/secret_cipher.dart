import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

/// Compatibility: enc:v1: + base64url(nonce[12] + mac[16] + ciphertext).
class SecretCipher {
  SecretCipher(String key)
      : _key = SecretKey(sha256.convert(utf8.encode(key)).bytes) {
    if (key.isEmpty) throw ArgumentError('Chave não configurada.');
  }

  final SecretKey _key;
  final _algorithm = AesGcm.with256bits();

  Future<String> encrypt(String value) async {
    if (value.isEmpty) throw ArgumentError('Valor vazio.');
    final box = await _algorithm.encrypt(utf8.encode(value), secretKey: _key);
    final bytes = <int>[...box.nonce, ...box.mac.bytes, ...box.cipherText];
    return 'enc:v1:' + base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<String> decrypt(String stored) async {
    if (!stored.startsWith('enc:v1:')) {
      throw const FormatException('Formato não reconhecido.');
    }
    final bytes = base64Url.decode(base64Url.normalize(stored.substring(7)));
    if (bytes.length < 29) throw const FormatException('Valor inválido.');
    final box = SecretBox(bytes.sublist(28),
        nonce: bytes.sublist(0, 12), mac: Mac(bytes.sublist(12, 28)));
    return utf8.decode(await _algorithm.decrypt(box, secretKey: _key));
  }
}
