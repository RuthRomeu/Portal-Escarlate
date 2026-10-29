import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:portal_contracts/portal_contracts.dart';
import 'package:portal_core/portal_core.dart';

import 'auth_user.dart';

class SessionIdentity {
  const SessionIdentity(this.id, this.email, this.role);
  final String id;
  final String email;
  final String role;
}

class SessionTokens {
  SessionTokens(this.secret, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    if (secret.isEmpty) throw ArgumentError('AUTH_SECRET ausente.');
  }

  final String secret;
  final DateTime Function() _clock;
  static const cookieName = 'portal_session';
  static const ttlSeconds = 7 * 24 * 60 * 60;

  String _encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  String _sign(String data) {
    final digest = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(data));
    return _encode(digest.bytes);
  }

  String issue(AuthUser user) {
    final now = _clock().toUtc().millisecondsSinceEpoch ~/ 1000;
    final header = _encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final payload = _encode(utf8.encode(jsonEncode({
      'sub': user.id,
      'email': user.email,
      'role': user.role,
      'jti': newEventId(),
      'iat': now,
      'exp': now + ttlSeconds,
    })));
    final unsigned = header + '.' + payload;
    return unsigned + '.' + _sign(unsigned);
  }

  SessionIdentity? verify(String? token) {
    if (token == null || token.length > 4096) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final unsigned = parts[0] + '.' + parts[1];
    if (!safeTokenEquals(_sign(unsigned), parts[2])) return null;
    try {
      final header = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))));
      final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (header is! Map || header['alg'] != 'HS256' ||
          header['typ'] != 'JWT' || claims is! Map) return null;
      final now = _clock().toUtc().millisecondsSinceEpoch ~/ 1000;
      final exp = claims['exp'];
      final id = claims['sub'];
      final email = claims['email'];
      final role = claims['role'];
      if (exp is! int || exp <= now ||
          id is! String || id.isEmpty ||
          email is! String || validateEmail(email) != null ||
          role is! String || (role != 'user' && role != 'admin')) return null;
      return SessionIdentity(id, normalizeEmail(email), role);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  String cookie(String token, {bool secure = false}) =>
      cookieName + '=' + token + '; Path=/; HttpOnly; SameSite=Lax; ' +
      'Max-Age=' + ttlSeconds.toString() + (secure ? '; Secure' : '');

  List<String> expiredCookies({
    bool secure = false,
    String? appUrl,
  }) {
    final base = cookieName + '=; Path=/; HttpOnly; SameSite=Lax; ' +
        'Max-Age=0' + (secure ? '; Secure' : '');
    final cookies = <String>[base];
    final host = Uri.tryParse(appUrl ?? '')?.host ?? '';
    if (host.isNotEmpty && host != 'localhost' &&
        InternetProtocolHelper.isDomain(host)) {
      cookies.add(base + '; Domain=' + host);
      cookies.add(base + '; Domain=.' + host);
    }
    return cookies;
  }
}

abstract final class InternetProtocolHelper {
  static bool isDomain(String host) =>
      !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host) &&
      !host.contains(':');
}
