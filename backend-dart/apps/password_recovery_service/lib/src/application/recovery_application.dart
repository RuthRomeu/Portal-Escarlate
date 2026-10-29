import 'package:portal_contracts/portal_contracts.dart';

import '../domain/recovery.dart';
import '../domain/recovery_tokens.dart';

class RecoveryRateLimiter {
  RecoveryRateLimiter({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final Map<String, _Bucket> _email = {};
  final Map<String, _Bucket> _ip = {};
  static const window = Duration(minutes: 5);

  bool _consume(Map<String, _Bucket> map, String key, int max) {
    final now = _clock();
    if (map.length > 10000) {
      map.removeWhere((_, value) => !value.until.isAfter(now));
      if (map.length > 10000 && !map.containsKey(key)) return false;
    }
    final bucket = map[key];
    if (bucket == null || !bucket.until.isAfter(now)) {
      map[key] = _Bucket(1, now.add(window));
      return true;
    }
    if (bucket.count >= max) return false;
    bucket.count++;
    return true;
  }

  bool allow(String email, String ip) {
    final byEmail = _consume(_email, email, 3);
    final byIp = _consume(_ip, ip, 10);
    return byEmail && byIp;
  }
}

class _Bucket {
  _Bucket(this.count, this.until);
  int count;
  final DateTime until;
}

class RecoveryApplication {
  RecoveryApplication({
    required this.repository,
    required this.auth,
    required this.tokens,
    required this.appUrl,
    RecoveryRateLimiter? limiter,
  }) : limiter = limiter ?? RecoveryRateLimiter();

  final RecoveryRepository repository;
  final RecoveryAuthClient auth;
  final RecoveryTokens tokens;
  final Uri appUrl;
  final RecoveryRateLimiter limiter;

  static const genericMessage =
      'Se este e-mail estiver cadastrado, enviaremos um link de recuperacao em instantes.';

  Future<void> forgot(String emailInput, String ip) async {
    final email = normalizeRecoveryEmail(emailInput);
    if (!limiter.allow(email, ip)) {
      throw const RecoveryException(429,
          'Muitas tentativas de recuperacao. Tente novamente em instantes.');
    }
    // Always respond with generic success for unknown users.
    if (!await auth.userExists(email)) return;
    final requestId = newEventId();
    await repository.request(
      requestId: requestId,
      email: email,
      tokenHash: tokens.digest(tokens.codeFor(requestId)),
      expiresAt: tokens.clock().toUtc().add(RecoveryTokens.ttl),
    );
  }

  Future<bool> reset(String code, String password) async {
    if (code.length != 43 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) {
      return false;
    }
    return repository.reset(
      tokens.digest(code),
      (pending) => auth.changePassword(pending, password),
    );
  }

  Future<Map<String, String>?> emailRequest(String requestId) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(requestId)) return null;
    final pending = await repository.findRequest(requestId);
    if (pending == null) return null;
    return {
      'to': pending.email,
      'actionUrl': tokens.actionUrl(appUrl, pending.id).toString(),
    };
  }
}
