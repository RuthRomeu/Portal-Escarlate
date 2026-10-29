import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic secret token derived from an unpredictable UUID requestId.
/// Only the SHA-256 digest is persisted. Neither the event nor DB stores
/// the action URL or bearer token.
class RegistrationTokens {
  RegistrationTokens(this.secret, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now {
    if (secret.length < 32) {
      throw ArgumentError('REGISTRATION_TOKEN_SECRET deve ter >=32 caracteres.');
    }
  }

  final String secret;
  final DateTime Function() clock;
  static const ttl = Duration(minutes: 5);

  String codeFor(String requestId) {
    final raw = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('registration:' + requestId));
    return base64Url.encode(raw.bytes).replaceAll('=', '');
  }

  String digest(String code) => sha256.convert(utf8.encode(code)).toString();

  Uri actionUrl(Uri appUrl, String requestId) {
    if (!appUrl.hasAuthority ||
        (appUrl.scheme != 'https' &&
            !(appUrl.scheme == 'http' && appUrl.host == 'localhost'))) {
      throw ArgumentError('APP_URL deve usar HTTPS ou localhost.');
    }
    return appUrl.resolve('/verify-email').replace(
      queryParameters: {'code': codeFor(requestId)},
    );
  }
}
