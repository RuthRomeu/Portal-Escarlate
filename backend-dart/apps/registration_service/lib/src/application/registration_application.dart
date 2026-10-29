import 'package:portal_contracts/portal_contracts.dart';

import '../domain/registration.dart';
import '../domain/registration_tokens.dart';

abstract interface class RegistrationPasswordHasher {
  Future<String> hash(String password);
}

class RegistrationLimiter {
  RegistrationLimiter({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final Map<String, _Counter> _email = {};
  final Map<String, _Counter> _ip = {};
  static const window = Duration(minutes: 5);

  bool _consume(Map<String, _Counter> map, String key, int max) {
    final now = _clock();
    if (map.length > 10000) {
      map.removeWhere((_, item) => !item.expires.isAfter(now));
      if (map.length > 10000 && !map.containsKey(key)) return false;
    }
    final item = map[key];
    if (item == null || !item.expires.isAfter(now)) {
      map[key] = _Counter(1, now.add(window));
      return true;
    }
    if (item.count >= max) return false;
    item.count++;
    return true;
  }

  bool allow(String email, String ip) {
    final a = _consume(_email, email, 3);
    final b = _consume(_ip, ip, 10);
    return a && b;
  }
}

class _Counter {
  _Counter(this.count, this.expires);
  int count;
  DateTime expires;
}

class RegistrationApplication {
  RegistrationApplication({
    required this.repository,
    required this.auth,
    required this.hasher,
    required this.tokens,
    required this.appUrl,
    RegistrationLimiter? limiter,
  }) : limiter = limiter ?? RegistrationLimiter();

  final RegistrationRepository repository;
  final AuthRegistrationClient auth;
  final RegistrationPasswordHasher hasher;
  final RegistrationTokens tokens;
  final Uri appUrl;
  final RegistrationLimiter limiter;

  static const requestMessage =
      'Se este e-mail puder receber acesso, enviaremos um link de confirmacao em instantes.';

  Future<void> request(Map<String, dynamic> body, String ip) async {
    final email = normalizeRegistrationEmail(body['email'] as String);
    if (!limiter.allow(email, ip)) {
      throw const RegistrationException(429,
          'Muitas tentativas de cadastro. Tente novamente em instantes.');
    }
    if (await auth.userExists(email)) {
      throw const RegistrationException(409,
          'Ja existe uma conta com este e-mail. Use o login para entrar no portal.');
    }
    final hash = await hasher.hash(body['password'] as String);
    final id = newEventId();
    await repository.request(
      requestId: id,
      email: email,
      passwordHash: hash,
      tokenHash: tokens.digest(tokens.codeFor(id)),
      expiresAt: tokens.clock().toUtc().add(RegistrationTokens.ttl),
    );
  }

  Future<bool> verify(String code) async {
    if (code.length != 43 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) {
      return false;
    }
    return repository.verify(tokens.digest(code), auth.createUser);
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
