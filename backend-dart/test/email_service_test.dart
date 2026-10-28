import 'dart:convert';

import 'package:auth_service/auth_service.dart';
import 'package:email_service/email_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_http/session_verifier.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class FakeEmailConnections implements EmailConnectionRepository {
  final items = <String, EmailConnection>{};

  @override
  Future<List<EmailConnection>> list() async => items.values.toList();

  @override
  Future<EmailConnection?> active() async {
    final values = items.values.where((c) => c.active).toList();
    values.sort((a, b) => a.priority.compareTo(b.priority));
    return values.isEmpty ? null : values.first;
  }

  @override
  Future<EmailConnection> save(String email, String token,
      {int priority = 100}) async {
    final now = DateTime.utc(2026);
    final item = EmailConnection(id: '11111111-1111-4111-8111-111111111111',
        provider: 'gmail', email: email, refreshToken: token,
        active: true, priority: priority, createdAt: now, updatedAt: now);
    items[item.id] = item;
    return item;
  }

  @override
  Future<EmailConnection?> changePriority(String id, int priority) async {
    final item = items[id];
    if (item == null) return null;
    final updated = EmailConnection(id: item.id, provider: item.provider,
        email: item.email, refreshToken: item.refreshToken, active: item.active,
        priority: priority, createdAt: item.createdAt,
        updatedAt: DateTime.utc(2026));
    items[id] = updated;
    return updated;
  }

  @override
  Future<bool> delete(String id) async => items.remove(id) != null;
}

void main() {
  test('AES-GCM encrypt/decrypt round-trip e formato Node', () async {
    final cipher = SecretCipher('secret-for-tests');
    final encrypted = await cipher.encrypt('refresh-token-value');
    expect(encrypted, startsWith('enc:v1:'));
    expect(encrypted, isNot(contains('refresh-token-value')));
    expect(await cipher.decrypt(encrypted), 'refresh-token-value');
    expect(
        () => cipher.decrypt('plaintext-token'), throwsA(isA<FormatException>()));
  });

  test('Google OAuth state assinado, expirado ou adulterado', () {
    final now = DateTime.utc(2026, 10, 28, 20);
    final oauth = GoogleOAuth(
      client: MockClient((_) async => http.Response('{}', 200)),
      clientId: 'id', clientSecret: 'secret',
      redirectUri: 'http://localhost:3100/api/google/callback',
      stateSecret: 'state-secret', appUrl: 'http://localhost:5173',
      clock: () => now,
    );
    final state = oauth.stateFor('admin-1', 'admin@example.com');
    expect(oauth.parseState(state)?['sub'], 'admin-1');
    expect(oauth.parseState(state + 'x'), isNull);
    final expired = GoogleOAuth(
      client: MockClient((_) async => http.Response('{}', 200)),
      clientId: 'id', clientSecret: 'secret',
      redirectUri: 'http://localhost:3100/api/google/callback',
      stateSecret: 'state-secret', appUrl: 'http://localhost:5173',
      clock: () => now.add(const Duration(minutes: 11)),
    );
    expect(expired.parseState(state), isNull);
  });

  test('rotas administrativas recusam usuario comum', () async {
    final repo = FakeEmailConnections();
    final httpClient = MockClient((_) async => http.Response('{}', 200));
    final oauth = GoogleOAuth(
      client: httpClient, clientId: 'id', clientSecret: 'secret',
      redirectUri: 'http://localhost:3100/api/google/callback',
      stateSecret: 'shared', appUrl: 'http://localhost:5173',
    );
    final api = EmailApi(repo, oauth,
        GmailDelivery(repo, oauth, httpClient), SessionVerifier('shared'));
    final router = Router();
    api.registerRoutes(router);
    final anonymous = await router.call(
        Request('GET', Uri.parse('http://localhost/api/email-connections')));
    expect(anonymous.statusCode, 401);

    final token = SessionTokens('shared').issue(
        const AuthUser(id: 'user-1', email: 'user@example.com', role: 'user'));
    final denied = await router.call(Request(
      'GET', Uri.parse('http://localhost/api/email-connections'),
      headers: {'cookie': 'portal_session=' + token},
    ));
    expect(denied.statusCode, 403);
  });

  test('lista nao revela refresh token; prioridade e remocao funcionam', () async {
    final repo = FakeEmailConnections();
    final id = (await repo.save('sender@gmail.com', 'secret-refresh-token')).id;
    final client = MockClient((req) async {
      if (req.url.path.contains('token')) {
        return http.Response(jsonEncode({'access_token': 'access'}), 200);
      }
      return http.Response('{}', 200);
    });
    final oauth = GoogleOAuth(
      client: client, clientId: 'id', clientSecret: 'secret',
      redirectUri: 'http://localhost:3100/api/google/callback',
      stateSecret: 'shared', appUrl: 'http://localhost:5173',
    );
    final api = EmailApi(repo, oauth,
        GmailDelivery(repo, oauth, client), SessionVerifier('shared'));
    final router = Router();
    api.registerRoutes(router);
    final token = SessionTokens('shared').issue(
        const AuthUser(id: 'admin-1', email: 'admin@example.com',
            role: 'admin'));
    final headers = {'cookie': 'portal_session=' + token};
    final list = await router.call(Request('GET',
        Uri.parse('http://localhost/api/email-connections'),
        headers: headers));
    final body = await list.readAsString();
    expect(list.statusCode, 200);
    expect(body, contains('sender@gmail.com'));
    expect(body, isNot(contains('secret-refresh-token')));
    final priority = await router.call(Request('PATCH',
        Uri.parse('http://localhost/api/email-connections/' +
            id + '/priority'), headers: headers,
        body: jsonEncode({'priority': 4})));
    expect(priority.statusCode, 200);
    final deleted = await router.call(Request('DELETE',
        Uri.parse('http://localhost/api/email-connections/' + id),
        headers: headers));
    expect(deleted.statusCode, 204);
  });
}
