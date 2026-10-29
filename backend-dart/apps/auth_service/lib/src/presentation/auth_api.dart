import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../domain/auth_user.dart';
import '../domain/passwords.dart';
import '../domain/sessions.dart';
import '../infrastructure/postgres_auth_repository.dart';

class AuthRateLimiter {
  AuthRateLimiter({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final Map<String, _Bucket> _attempts = {};
  static const _window = Duration(minutes: 10);
  static const _perEmail = 5;
  static const _maxKeys = 10000;

  bool allow(String email) {
    final now = _clock();
    if (_attempts.length >= _maxKeys) {
      _attempts.removeWhere((_, bucket) => !bucket.expires.isAfter(now));
      if (_attempts.length >= _maxKeys && !_attempts.containsKey(email)) {
        return false;
      }
    }
    final old = _attempts[email];
    if (old == null || !old.expires.isAfter(now)) {
      _attempts[email] = _Bucket(1, now.add(_window));
      return true;
    }
    if (old.count >= _perEmail) return false;
    old.count++;
    return true;
  }

  void clear(String email) => _attempts.remove(email);
}

class _Bucket {
  _Bucket(this.count, this.expires);
  int count;
  final DateTime expires;
}

class _BodyProblem implements Exception {
  const _BodyProblem(this.status, this.message);
  final int status;
  final String message;
}

class AuthApi {
  AuthApi({
    required this.repository,
    required this.passwords,
    required this.sessions,
    this.secureCookies = false,
    this.appUrl,
    AuthRateLimiter? rateLimiter,
  }) : _rateLimiter = rateLimiter ?? AuthRateLimiter();

  final AuthRepository repository;
  final PasswordService passwords;
  final SessionTokens sessions;
  final bool secureCookies;
  final String? appUrl;
  final AuthRateLimiter _rateLimiter;

  void registerRoutes(Router router) {
    router.post('/api/auth/login',
        (Request request) => _guard(() => _login(request),
            'Nao foi possivel autenticar agora.'));
    router.post('/api/auth/logout',
        (Request request) => _guard(() => _logout(request),
            'Nao foi possivel encerrar a sessao.'));
    router.get('/api/auth/me',
        (Request request) => _guard(() => _me(request),
            'Nao foi possivel validar a sessao.'));
    router.get('/internal/auth/users/exists',
        (Request request) => _guard(() => _exists(request),
            'Nao foi possivel consultar o usuario.'));
    router.post('/internal/auth/users',
        (Request request) => _guard(() => _create(request),
            'Nao foi possivel criar o usuario.'));
    router.post('/internal/auth/users/password',
        (Request request) => _guard(() => _updatePassword(request),
            'Nao foi possivel atualizar a senha.'));
  }

  Future<Response> _guard(
      Future<Response> Function() run, String failureMessage) async {
    try {
      return await run();
    } on _BodyProblem catch (error) {
      return _reply(error.status, {'message': error.message});
    } catch (error) {
      // Não registrar payloads, senhas ou tokens nos logs.
      print('[auth] request failed: ' + error.runtimeType.toString());
      return _reply(500, {'message': failureMessage});
    }
  }

  Response _reply(int status, Object body, {List<String>? cookies}) {
    final headers = <String, Object>{
      'content-type': 'application/json; charset=utf-8',
      if (cookies != null && cookies.isNotEmpty) 'set-cookie': cookies,
    };
    return Response(status, body: jsonEncode(body), headers: headers);
  }

  Future<Map<String, dynamic>> _readBody(Request request) async {
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > 16384) {
        throw const _BodyProblem(413, 'Dados da requisicao muito grandes.');
      }
    }
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('JSON object required');
      }
      return value;
    } on FormatException {
      throw const _BodyProblem(400, 'Nao foi possivel ler os dados da requisicao.');
    }
  }

  Response? _invalidFields(Map<String, dynamic> body,
      {required bool requirePassword, bool strongPassword = false}) {
    final errors = <String, List<String>>{};
    final emailError = validateEmail(body['email']);
    if (emailError != null) errors['email'] = [emailError];
    if (requirePassword) {
      String? passwordError;
      if (strongPassword) {
        passwordError = validateNewPassword(body['password']);
      } else if (body['password'] is! String ||
          (body['password'] as String).isEmpty) {
        passwordError = 'Informe sua senha.';
      }
      if (passwordError != null) errors['password'] = [passwordError];
    }
    if (errors.isEmpty) return null;
    return _reply(400, {
      'message': errors.values.first.first,
      'fieldErrors': errors,
    });
  }

  List<String> _clearCookies() =>
      sessions.expiredCookies(secure: secureCookies, appUrl: appUrl);

  Iterable<String> _cookieTokens(Request request) sync* {
    final cookie = request.headers['cookie'];
    if (cookie == null) return;
    for (final part in cookie.split(';')) {
      final pair = part.trim().split('=');
      if (pair.length >= 2 && pair.first == SessionTokens.cookieName) {
        yield pair.skip(1).join('=');
      }
    }
  }

  Future<Response> _login(Request request) async {
    final body = await _readBody(request);
    final invalid = _invalidFields(body, requirePassword: true);
    if (invalid != null) return invalid;
    final email = normalizeEmail(body['email'] as String);
    final password = body['password'] as String;

    if (!_rateLimiter.allow(email)) {
      return _reply(429, {
        'message': 'Muitas tentativas de login. Tente novamente em instantes.',
      });
    }
    final user = await repository.findByEmail(email);
    if (user == null) {
      return _reply(401, {'code': 'user_not_found', 'message': 'E-mail não cadastrado.'});
    }
    if (user.passwordHash == null ||
        !await passwords.verify(password, user.passwordHash!)) {
      return _reply(401, {'message': 'Credenciais invalidas.'});
    }
    _rateLimiter.clear(email);
    final token = sessions.issue(user);
    return _reply(200, {'user': user.toSessionJson()}, cookies: [
      ..._clearCookies(),
      sessions.cookie(token, secure: secureCookies),
    ]);
  }

  Future<Response> _logout(Request request) async =>
      _reply(200, {'message': 'Sessao encerrada.'},
          cookies: _clearCookies());

  Future<Response> _me(Request request) async {
    for (final token in _cookieTokens(request)) {
      final identity = sessions.verify(token);
      if (identity == null) continue;
      final user = await repository.findByEmail(identity.email);
      if (user != null && user.id == identity.id) {
        return _reply(200, {'user': user.toSessionJson()});
      }
    }
    return _reply(401, {'message': 'Sessao invalida.'},
        cookies: _clearCookies());
  }

  Future<Response> _exists(Request request) async {
    final email = request.url.queryParameters['email'];
    if (email == null || email.trim().isEmpty) {
      return _reply(400, {'message': 'E-mail ausente.'});
    }
    if (validateEmail(email) != null) {
      return _reply(400, {'message': 'Informe um e-mail válido.'});
    }
    final user = await repository.findByEmail(email);
    return _reply(200, {'exists': user != null});
  }

  Future<Response> _create(Request request) async {
    final body = await _readBody(request);
    if (validateEmail(body['email']) != null ||
        body['passwordHash'] is! String ||
        !(body['passwordHash'] as String).startsWith(r'$argon2id$v=19$')) {
      return _reply(400, {'message': 'Dados do usuario invalidos.'});
    }
    final created = await repository.createUser(
        body['email'] as String, body['passwordHash'] as String);
    if (created == null) {
      return _reply(409, {'message': 'Ja existe uma conta com este e-mail.'});
    }
    return _reply(201, {'message': 'Usuario criado com sucesso.'});
  }

  Future<Response> _updatePassword(Request request) async {
    final body = await _readBody(request);
    final invalid = _invalidFields(
        body, requirePassword: true, strongPassword: true);
    if (invalid != null) return invalid;
    final passwordHash = await passwords.hash(body['password'] as String);
    final user = await repository.updatePassword(
        body['email'] as String, passwordHash);
    if (user == null) {
      return _reply(404, {'message': 'Usuario nao encontrado.'});
    }
    return _reply(200, {'message': 'Senha atualizada com sucesso.'});
  }
}
