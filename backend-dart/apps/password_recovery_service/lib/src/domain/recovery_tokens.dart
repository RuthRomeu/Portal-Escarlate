import 'dart:convert';
import 'package:crypto/crypto.dart';

/// The email token is a keyed derivation of an unpredictable request UUID.
/// Only the SHA-256 digest is saved in PostgreSQL; NATS sees requestId only.
class RecoveryTokens {
  RecoveryTokens(this.secret, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now {
    if (secret.length < 32) {
      throw ArgumentError('PASSWORD_RECOVERY_TOKEN_SECRET precisa de >=32 caracteres.');
    }
  }

  final String secret;
  final DateTime Function() clock;
  static const ttl = Duration(minutes: 5);

  String codeFor(String requestId) {
    final digest = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('password-recovery:' + requestId));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String digest(String code) => sha256.convert(utf8.encode(code)).toString();

  Uri actionUrl(Uri appUrl, String requestId) {
    if (!appUrl.hasAuthority ||
        (appUrl.scheme != 'https' &&
            !(appUrl.scheme == 'http' && appUrl.host == 'localhost'))) {
      throw ArgumentError('APP_URL deve ser HTTPS ou localhost.');
    }
    return appUrl.resolve('/reset-password').replace(
      queryParameters: {'code': codeFor(requestId)},
    );
  }
}
