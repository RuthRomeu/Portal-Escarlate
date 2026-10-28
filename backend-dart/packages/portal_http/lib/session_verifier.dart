import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:portal_core/portal_core.dart';
import 'package:shelf/shelf.dart';

class AuthenticatedSession {
  const AuthenticatedSession(this.userId, this.email, this.role);
  final String userId, email, role;
}

/// Verifica apenas as assinaturas de sessão compatíveis com o Auth Node.
/// O mesmo AUTH_SECRET deve ser configurado nos serviços que validam cookies.
class SessionVerifier {
  SessionVerifier(this.secret, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final String secret;
  final DateTime Function() clock;

  AuthenticatedSession? user(Request request) {
    final header = request.headers['cookie'];
    if (header == null || secret.isEmpty) return null;
    for (final part in header.split(';')) {
      final index = part.indexOf('=');
      if (index < 0 || part.substring(0, index).trim() != 'portal_session') {
        continue;
      }
      final token = part.substring(index + 1).trim();
      final result = verify(token);
      if (result != null) return result;
    }
    return null;
  }

  AuthenticatedSession? verify(String token) {
    if (token.length > 4096) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final unsigned = parts[0] + '.' + parts[1];
    final signature = base64Url.encode(Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(unsigned)).bytes).replaceAll('=', '');
    if (!safeTokenEquals(parts[2], signature)) return null;
    try {
      final header = jsonDecode(utf8.decode(
          base64Url.decode(base64Url.normalize(parts[0]))));
      final data = jsonDecode(utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1]))));
      if (header is! Map || header['alg'] != 'HS256' ||
          data is! Map || data['exp'] is! int ||
          data['sub'] is! String || data['email'] is! String ||
          data['role'] is! String) return null;
      final now = clock().toUtc().millisecondsSinceEpoch ~/ 1000;
      if ((data['exp'] as int) <= now) return null;
      return AuthenticatedSession(
          data['sub'] as String,
          data['email'] as String,
          data['role'] as String);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
