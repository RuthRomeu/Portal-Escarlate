import 'dart:convert';
import 'package:password_recovery_service/password_recovery_service.dart';
import 'package:portal_http/portal_http.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class FakeRepo implements RecoveryRepository {
  final rows = <String, PendingRecovery>{};
  final hashes = <String, String>{};
  final events = <String>[];
  final now = DateTime.utc(2026, 10, 28, 20);

  @override
  Future<PendingRecovery> request({
    required String requestId, required String email,
    required String tokenHash, required DateTime expiresAt,
  }) async {
    rows.removeWhere((_, row) => row.email == email && row.consumedAt == null);
    final row = PendingRecovery(id: requestId, email: email, expiresAt: expiresAt);
    rows[requestId] = row;
    hashes[tokenHash] = requestId;
    events.add('portal.password_recovery.requested.v1');
    return row;
  }

  @override
  Future<PendingRecovery?> findRequest(String id) async {
    final row = rows[id];
    return row != null && row.isValidAt(now) ? row : null;
  }

  @override
  Future<bool> reset(String hash,
      Future<void> Function(PendingRecovery) update) async {
    final id = hashes[hash];
    final row = id == null ? null : rows[id];
    if (row == null || !row.isValidAt(now)) return false;
    await update(row);
    rows[id!] = PendingRecovery(id: row.id, email: row.email,
      expiresAt: row.expiresAt, consumedAt: now);
    events.add('portal.auth.password_reset.v1');
    return true;
  }
}

class FakeAuth implements RecoveryAuthClient {
  final users = <String>{'user@example.com'};
  int updated = 0;
  bool fail = false;

  @override
  Future<bool> userExists(String email) async => users.contains(email);

  @override
  Future<void> changePassword(PendingRecovery row, String password) async {
    if (fail) throw const RecoveryException(503, 'Auth indisponivel.');
    updated++;
  }
}

void main() {
  late FakeRepo repo;
  late FakeAuth auth;
  late RecoveryApplication app;
  late Handler handler;

  setUp(() {
    repo = FakeRepo();
    auth = FakeAuth();
    final tokens = RecoveryTokens(
      'a-long-password-recovery-test-secret-2026',
      clock: () => DateTime.utc(2026, 10, 28, 20));
    app = RecoveryApplication(
      repository: repo, auth: auth, tokens: tokens,
      appUrl: Uri.parse('https://example.com'));
    final router = Router();
    RecoveryApi(app).registerRoutes(router);
    handler = const Pipeline().addMiddleware(internalAccess('token'))
        .addHandler(router.call);
  });

  Request req(String method, String path, {Object? body, bool internal = true}) =>
      Request(method, Uri.parse('http://localhost' + path), headers: {
        if (internal) 'x-internal-token': 'token',
        'x-forwarded-for': '203.0.113.12',
        'content-type': 'application/json',
      }, body: body == null ? null : jsonEncode(body));

  Future<String> issue() async {
    final response = await handler(req('POST', '/api/auth/password/forgot',
      body: {'email': ' USER@EXAMPLE.COM '}));
    expect(response.statusCode, 200);
    final id = repo.rows.keys.single;
    final link = await handler(req('GET',
      '/internal/password-recovery/email-requests/' + id));
    expect(link.statusCode, 200);
    final data = jsonDecode(await link.readAsString());
    expect(data['to'], 'user@example.com');
    return Uri.parse(data['actionUrl'] as String).queryParameters['code']!;
  }

  test('recovery code works once; Auth failure preserves token', () async {
    final code = await issue();
    auth.fail = true;
    final payload = {'password': 'Nova#Senha123', 'confirmPassword': 'Nova#Senha123'};
    var response = await handler(req('POST',
      '/api/auth/password/reset?code=' + code, body: payload));
    expect(response.statusCode, 503);
    expect(repo.rows.values.single.consumedAt, isNull);
    auth.fail = false;
    response = await handler(req('POST',
      '/api/auth/password/reset?code=' + code, body: payload));
    expect(response.statusCode, 200);
    response = await handler(req('POST',
      '/api/auth/password/reset?code=' + code, body: payload));
    expect(response.statusCode, 400);
    expect(auth.updated, 1);
    expect(repo.events, contains('portal.auth.password_reset.v1'));
  });

  test('unknown email responds identically, without creating a token', () async {
    final a = await handler(req('POST', '/api/auth/password/forgot',
      body: {'email': 'user@example.com'}));
    final b = await handler(req('POST', '/api/auth/password/forgot',
      body: {'email': 'unknown@example.com'}));
    expect(a.statusCode, 200);
    expect(b.statusCode, 200);
    expect(await a.readAsString(), await b.readAsString());
    expect(repo.rows, hasLength(1));
  });

  test('reject invalid fields, absent code and anonymous internal request', () async {
    final invalid = await handler(req('POST', '/api/auth/password/forgot',
      body: {'email': 'not-email'}));
    expect(invalid.statusCode, 400);
    final reset = await handler(req('POST', '/api/auth/password/reset',
      body: {'password': '123', 'confirmPassword': 'wrong'}));
    expect(reset.statusCode, 400);
    final denied = await handler(req('GET',
      '/internal/password-recovery/email-requests/'
      '11111111-1111-4111-8111-111111111111', internal: false));
    expect(denied.statusCode, 403);
  });

  test('3 requests per email in five minutes', () async {
    for (var i = 0; i < 3; i++) {
      final result = await handler(req('POST', '/api/auth/password/forgot',
        body: {'email': 'user@example.com'}));
      expect(result.statusCode, 200);
    }
    final blocked = await handler(req('POST', '/api/auth/password/forgot',
      body: {'email': 'user@example.com'}));
    expect(blocked.statusCode, 429);
  });

  test('derived secret and HTTPS-only reset link', () {
    const id = '11111111-1111-4111-8111-111111111111';
    final code = app.tokens.codeFor(id);
    expect(code.length, 43);
    expect(app.tokens.digest(code).length, 64);
    expect(() => app.tokens.actionUrl(Uri.parse('http://evil.test'), id),
      throwsArgumentError);
  });
}
