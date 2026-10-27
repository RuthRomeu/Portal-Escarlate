import 'dart:convert';

import 'package:auth_service/auth_service.dart';
import 'package:portal_http/portal_http.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class _FakeRepository implements AuthRepository {
  final users = <String, AuthUser>{};

  @override
  Future<AuthUser?> findByEmail(String email) async =>
      users[normalizeEmail(email)];

  @override
  Future<AuthUser?> createUser(String email, String passwordHash) async {
    email = normalizeEmail(email);
    if (users.containsKey(email)) return null;
    final user = AuthUser(id: 'id-1', email: email, role: 'user',
        passwordHash: passwordHash);
    users[email] = user;
    return user;
  }

  @override
  Future<AuthUser?> updatePassword(String email, String passwordHash) async {
    email = normalizeEmail(email);
    final existing = users[email];
    if (existing == null) return null;
    final updated = AuthUser(id: existing.id, email: email,
        role: existing.role, passwordHash: passwordHash);
    users[email] = updated;
    return updated;
  }
}

class _FakePasswords implements PasswordService {
  @override
  Future<String> hash(String password) async => 'hash:' + password;

  @override
  Future<bool> verify(String password, String encodedHash) async =>
      encodedHash == 'hash:' + password;
}

Handler _handler(_FakeRepository repository, SessionTokens sessions,
    {AuthRateLimiter? limiter}) {
  final api = AuthApi(
    repository: repository,
    passwords: _FakePasswords(),
    sessions: sessions,
    rateLimiter: limiter,
  );
  final routes = Router();
  api.registerRoutes(routes);
  return const Pipeline()
      .addMiddleware(internalAccess('internal-test'))
      .addHandler(routes.call);
}

Request _request(String method, String path,
    {Object? body, Map<String, String> headers = const {}}) =>
    Request(method, Uri.parse('http://localhost' + path),
        headers: {'x-internal-token': 'internal-test', ...headers},
        body: body == null ? null : jsonEncode(body));

void main() {
  late _FakeRepository repository;
  late SessionTokens sessions;
  late Handler handler;

  setUp(() {
    repository = _FakeRepository();
    repository.users['user@example.com'] = const AuthUser(
        id: 'id-1', email: 'user@example.com',
        role: 'user', passwordHash: 'hash:Teste#Senha123');
    sessions = SessionTokens('test-secret');
    handler = _handler(repository, sessions);
  });

  test('login, /me e logout preservam contrato e cookie', () async {
    final login = await handler(_request('POST', '/api/auth/login', body: {
      'email': ' User@Example.com ', 'password': 'Teste#Senha123'
    }));
    expect(login.statusCode, 200);
    final cookies = login.headersAll['set-cookie']!;
    final active = cookies.last.split(';').first;
    expect(active, startsWith('portal_session='));
    final payload = jsonDecode(await login.readAsString());
    expect(payload['user']['email'], 'user@example.com');
    expect(payload['user'].containsKey('passwordHash'), false);

    final me = await handler(_request('GET', '/api/auth/me',
        headers: {'cookie': active}));
    expect(me.statusCode, 200);
    expect((jsonDecode(await me.readAsString()))['user']['id'], 'id-1');

    final logout = await handler(_request('POST', '/api/auth/logout'));
    expect(logout.statusCode, 200);
    expect(logout.headersAll['set-cookie']!.first, contains('Max-Age=0'));
  });

  test('login incorreto e usuario ausente retornam 401', () async {
    final invalid = await handler(_request('POST', '/api/auth/login', body: {
      'email': 'user@example.com', 'password': 'incorrect'
    }));
    expect(invalid.statusCode, 401);
    final missing = await handler(_request('POST', '/api/auth/login', body: {
      'email': 'missing@example.com', 'password': 'anything'
    }));
    expect(missing.statusCode, 401);
    expect((jsonDecode(await missing.readAsString()))['code'],
        'user_not_found');
  });

  test('limitação de tentativas bloqueia sexto login', () async {
    final limiter = AuthRateLimiter();
    final limitedHandler = _handler(repository, sessions, limiter: limiter);
    for (var i = 0; i < 5; i++) {
      final response = await limitedHandler(
          _request('POST', '/api/auth/login', body: {
        'email': 'user@example.com', 'password': 'incorrect'
      }));
      expect(response.statusCode, 401);
    }
    final blocked = await limitedHandler(
        _request('POST', '/api/auth/login', body: {
      'email': 'user@example.com', 'password': 'incorrect'
    }));
    expect(blocked.statusCode, 429);
  });

  test('rotas internas exigem token de serviço', () async {
    final request = Request('GET',
        Uri.parse('http://localhost/internal/auth/users/exists?email=x'));
    final response = await handler(request);
    expect(response.statusCode, 403);
  });

  test('consulta, cadastro e atualizacao de senha internos', () async {
    final exists = await handler(_request('GET',
        '/internal/auth/users/exists?email=user%40example.com'));
    expect((jsonDecode(await exists.readAsString()))['exists'], true);

    const phc = r'$argon2id$v=19$m=19456,t=2,p=1$c2FsdA$YWJj';
    final created = await handler(_request('POST',
        '/internal/auth/users', body: {
      'email': 'new@example.com', 'passwordHash': phc
    }));
    expect(created.statusCode, 201);
    final conflict = await handler(_request('POST',
        '/internal/auth/users', body: {
      'email': 'new@example.com', 'passwordHash': phc
    }));
    expect(conflict.statusCode, 409);
    final update = await handler(_request('POST',
        '/internal/auth/users/password', body: {
      'email': 'new@example.com', 'password': 'Nova#Senha123'
    }));
    expect(update.statusCode, 200);
    expect(repository.users['new@example.com']!.passwordHash,
        'hash:Nova#Senha123');
  });

  test('nao aceita JSON invalido e senha fraca', () async {
    final malformed = await handler(Request('POST',
      Uri.parse('http://localhost/api/auth/login'),
      headers: {'x-internal-token': 'internal-test'}, body: '{',
    ));
    expect(malformed.statusCode, 400);
    final weak = await handler(_request('POST',
        '/internal/auth/users/password', body: {
      'email': 'user@example.com', 'password': '123'
    }));
    expect(weak.statusCode, 400);
  });

  test('token emitido tem assinatura e expiração verificadas', () {
    const user = AuthUser(id: 'id-1', email: 'user@example.com', role: 'user');
    final token = sessions.issue(user);
    expect(sessions.verify(token)?.id, 'id-1');
    expect(sessions.verify(token + 'x'), isNull);
    final expired = SessionTokens('test-secret',
        clock: () => DateTime.utc(2040));
    expect(expired.verify(token), isNull);
  });

  test('aceita um token HMAC-SHA256 gerado no formato Node', () {
    const fixture = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJzdWIiOiIxMTExMTExMS0xMTExLTQxMTEtODExMS0xMTExMTExMTExMTEiLC'
        'JlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJyb2xlIjoidXNlciIsImp0a'
        'SI6ImEiLCJpYXQiOjE5MDAwMDAwMDAsImV4cCI6MTkwMDAwMzYwMH0.'
        '9bLxgT-tE4OQvQCNSlc9iRuoG58gF_iFrBzi-zFv6_M';
    final verifier = SessionTokens('test-secret-for-interop',
        clock: () => DateTime.fromMillisecondsSinceEpoch(
            1900001000 * 1000, isUtc: true));
    expect(verifier.verify(fixture)?.email, 'user@example.com');
  });

  test('Argon2id verifica um hash PHC com parametros do Node', () async {
    const fixture = r'$argon2id$v=19$m=19456,t=2,p=1$'
        'MDEyMzQ1Njc4OUFCQ0RFRg'
        r'$WhmKiwTcvnHLu6gHbX5zggEP1H6NqyJxBbaru2QE4ig';
    final password = Argon2Passwords();
    expect(await password.verify('Teste#Senha123', fixture), true);
    expect(await password.verify('senha-incorreta', fixture), false);
  });
}
