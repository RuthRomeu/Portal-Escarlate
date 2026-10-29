import 'dart:convert';

import 'package:registration_service/registration_service.dart';
import 'package:portal_http/portal_http.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class FakeRegistrationRepo implements RegistrationRepository {
  final rows = <String, PendingRegistration>{};
  final tokenHashes = <String, String>{};
  final events = <Map<String, Object>>[];
  bool failCreate = false;

  @override
  Future<PendingRegistration> request({
    required String requestId,
    required String email,
    required String passwordHash,
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    rows.removeWhere((_, row) => row.email == email && row.consumedAt == null);
    final row = PendingRegistration(
      id: requestId, email: email, passwordHash: passwordHash,
      expiresAt: expiresAt);
    rows[requestId] = row;
    tokenHashes[tokenHash] = requestId;
    events.add({
      'type': 'portal.registration.verification_requested.v1',
      'requestId': requestId,
    });
    return row;
  }

  @override
  Future<PendingRegistration?> findRequest(String id) async {
    final row = rows[id];
    return row != null && row.isValidAt(DateTime.utc(2026, 10, 28, 20))
        ? row
        : null;
  }

  @override
  Future<bool> verify(
    String tokenHash,
    Future<void> Function(PendingRegistration) create,
  ) async {
    final id = tokenHashes[tokenHash];
    final row = id == null ? null : rows[id];
    if (row == null || !row.isValidAt(DateTime.utc(2026, 10, 28, 20))) {
      return false;
    }
    await create(row);
    rows[id!] = PendingRegistration(
      id: row.id, email: row.email, passwordHash: row.passwordHash,
      expiresAt: row.expiresAt,
      consumedAt: DateTime.utc(2026, 10, 28, 20));
    events.add({
      'type': 'portal.registration.email_verified.v1',
      'requestId': id,
    });
    return true;
  }
}

class FakeAuth implements AuthRegistrationClient {
  final users = <String>{};
  var calls = 0;

  @override
  Future<bool> userExists(String email) async => users.contains(email);

  @override
  Future<void> createUser(PendingRegistration pending) async {
    calls++;
    users.add(pending.email);
  }
}

class FakeHasher implements RegistrationPasswordHasher {
  @override
  Future<String> hash(String password) async => 'argon2-test-' + password;
}

void main() {
  const valid = {
    'email': ' Example@Email.COM ',
    'password': 'Good#Pass123',
    'confirmPassword': 'Good#Pass123',
    'terms': true,
  };
  late FakeRegistrationRepo repository;
  late FakeAuth auth;
  late RegistrationTokens tokens;
  late RegistrationApplication app;
  late Handler handler;

  setUp(() {
    repository = FakeRegistrationRepo();
    auth = FakeAuth();
    tokens = RegistrationTokens(
      'a-very-long-test-secret-used-only-in-tests',
      clock: () => DateTime.utc(2026, 10, 28, 20),
    );
    app = RegistrationApplication(
      repository: repository, auth: auth, hasher: FakeHasher(),
      tokens: tokens, appUrl: Uri.parse('https://example.com'),
    );
    final routes = Router();
    RegistrationApi(app).registerRoutes(routes);
    handler = const Pipeline()
        .addMiddleware(internalAccess('internal-token'))
        .addHandler(routes.call);
  });

  Request request(String method, String route,
      {Object? body, String? token = 'internal-token'}) => Request(
      method, Uri.parse('http://registration' + route),
      headers: {
        if (token != null) 'x-internal-token': token,
        'x-forwarded-for': '203.0.113.10',
        'content-type': 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    );

  test('solicita cadastro, recupera link internamente, verifica uma vez', () async {
    final start = await handler(request('POST', '/api/auth/register/request',
        body: valid));
    expect(start.statusCode, 200);
    expect(repository.rows, hasLength(1));
    final row = repository.rows.values.single;
    expect(row.email, 'example@email.com');
    expect(row.passwordHash, startsWith('argon2-test-'));
    expect(repository.events.single.keys, contains('requestId'));
    expect(jsonEncode(repository.events), isNot(contains('code=')));

    final lookup = await handler(request('GET',
        '/internal/registration/email-requests/' + row.id));
    expect(lookup.statusCode, 200);
    final response = jsonDecode(await lookup.readAsString());
    expect(response['to'], 'example@email.com');
    final link = Uri.parse(response['actionUrl'] as String);
    expect(link.origin, 'https://example.com');
    final code = link.queryParameters['code']!;
    expect(code, isNotEmpty);
    expect(jsonEncode(repository.events), isNot(contains(code)));

    final confirmed = await handler(request('GET',
        '/api/auth/verify-email?code=' + code));
    expect(confirmed.statusCode, 200);
    expect(auth.calls, 1);
    final repeated = await handler(request('GET',
        '/api/auth/verify-email?code=' + code));
    expect(repeated.statusCode, 400);
    expect(auth.calls, 1);
    expect(repository.events.last['type'],
        'portal.registration.email_verified.v1');
  });

  test('valida senha, termos e confirmação antes de persistir', () async {
    final response = await handler(request('POST', '/api/auth/register',
      body: {
        'email': 'bad',
        'password': '123',
        'confirmPassword': 'wrong',
        'terms': false,
      }));
    expect(response.statusCode, 400);
    final body = jsonDecode(await response.readAsString());
    expect(body['fieldErrors'].keys, containsAll([
      'email', 'password', 'confirmPassword', 'terms',
    ]));
    expect(repository.rows, isEmpty);
  });

  test('rejeita e-mail já cadastrado', () async {
    auth.users.add('example@email.com');
    final response = await handler(
        request('POST', '/api/auth/register', body: valid));
    expect(response.statusCode, 409);
    expect(repository.rows, isEmpty);
  });

  test('protege consulta de links com token interno', () async {
    final response = await handler(request('GET',
      '/internal/registration/email-requests/' +
          '11111111-1111-4111-8111-111111111111',
      token: null));
    expect(response.statusCode, 403);
  });

  test('limita 3 pedidos para o mesmo e-mail em 5 minutos', () async {
    for (var i = 0; i < 3; i++) {
      final response = await handler(
          request('POST', '/api/auth/register/request', body: valid));
      expect(response.statusCode, 200);
    }
    final response = await handler(
        request('POST', '/api/auth/register/request', body: valid));
    expect(response.statusCode, 429);
  });

  test('token e URL são derivados, não armazenados em texto claro', () {
    const id = '11111111-1111-4111-8111-111111111111';
    final code = tokens.codeFor(id);
    expect(code.length, 43);
    expect(tokens.codeFor(id), code);
    expect(tokens.digest(code), hasLength(64));
    final link = tokens.actionUrl(Uri.parse('https://example.com'), id);
    expect(link.queryParameters['code'], code);
    expect(
      () => tokens.actionUrl(Uri.parse('http://evil.example'), id),
      throwsArgumentError,
    );
  });
}
