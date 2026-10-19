import 'package:api_gateway/api_gateway.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  final targets = {'auth': Uri.parse('http://127.0.0.1:3001')};

  test('roteia HTTP sincrono para serviço permitido', () {
    final request = Request('GET', Uri.parse('http://localhost/api/auth/health/live'));
    expect(resolveUpstream(request, targets).toString(),
      'http://127.0.0.1:3001/health/live');
  });

  test('nunca aceita host desconhecido na URL', () {
    final request = Request('GET', Uri.parse('http://localhost/api/inexistente/health/live'));
    expect(resolveUpstream(request, targets), isNull);
  });
}
