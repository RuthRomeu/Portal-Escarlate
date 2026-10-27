import 'dart:io';

import 'package:api_gateway/api_gateway.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer upstream;
  late HttpClient client;
  late Handler handler;

  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((request) async {
      expect(request.headers.value('x-internal-token'), 'internal-test-token');
      expect(request.headers.value('cookie'), 'portal_session=abc');
      request.response.headers
          .add('set-cookie', 'portal_session=xyz; Path=/; HttpOnly');
      request.response.headers
          .add('set-cookie', 'old_session=; Path=/; Max-Age=0');
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    client = HttpClient();
    handler = buildGatewayHandler(
      targets: {'auth': Uri.parse('http://127.0.0.1:' + upstream.port.toString())},
      internalToken: 'internal-test-token',
      origins: {'http://localhost:5173'},
      client: client,
    );
  });

  tearDown(() async {
    client.close(force: true);
    await upstream.close(force: true);
  });

  test('preserva cada Set-Cookie do upstream', () async {
    final request = Request(
      'POST',
      Uri.parse('http://localhost/api/auth/login'),
      headers: {
        'cookie': 'portal_session=abc',
        'origin': 'http://localhost:5173',
        'content-type': 'application/json',
      },
      body: '{}',
    );
    final response = await handler(request);
    expect(response.statusCode, 200);
    expect(response.headersAll['set-cookie'], hasLength(2));
    expect(response.headers['access-control-allow-origin'],
        'http://localhost:5173');
    expect(await response.readAsString(), '{"ok":true}');
  });

  test('bloqueia origem desconhecida sem contactar o serviço', () async {
    final response = await handler(Request('POST',
      Uri.parse('http://localhost/api/auth/login'),
      headers: {'origin': 'https://attacker.test'},
      body: '{}',
    ));
    expect(response.statusCode, 403);
  });

  test('OPTIONS permitido devolve CORS sem acessar o serviço', () async {
    final response = await handler(Request('OPTIONS',
      Uri.parse('http://localhost/api/auth/login'),
      headers: {'origin': 'http://localhost:5173'},
    ));
    expect(response.statusCode, 204);
    expect(response.headers['access-control-allow-credentials'], 'true');
  });

  test('rejeita payload acima do limite antes de chamar upstream', () async {
    final limited = buildGatewayHandler(
      targets: {'auth': Uri.parse('http://127.0.0.1:' + upstream.port.toString())},
      internalToken: 'internal-test-token',
      origins: {'http://localhost:5173'},
      client: client,
      maxRequestBytes: 4,
    );
    final response = await limited(Request('POST',
      Uri.parse('http://localhost/api/auth/login'),
      headers: {'origin': 'http://localhost:5173'},
      body: '123456789',
    ));
    expect(response.statusCode, 413);
  });
}
