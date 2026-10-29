import 'package:api_gateway/api_gateway.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  final targets = {
    'auth': Uri.parse('http://127.0.0.1:3001'),
    'registration': Uri.parse('http://127.0.0.1:3003'),
    'password-recovery': Uri.parse('http://127.0.0.1:3009'),
    'email': Uri.parse('http://127.0.0.1:3005'),
    'news': Uri.parse('http://127.0.0.1:3002'),
    'news-summary': Uri.parse('http://127.0.0.1:3006'),
    'article-summary': Uri.parse('http://127.0.0.1:3008'),
    'ai': Uri.parse('http://127.0.0.1:3004'),
  };

  test('preserva rotas públicas e parâmetros originais', () {
    final cases = <String, String>{
      '/api/auth/login': 'auth',
      '/api/auth/logout': 'auth',
      '/api/auth/me': 'auth',
      '/api/auth/register/request': 'registration',
      '/api/auth/verify-email?code=abc': 'registration',
      '/api/auth/password/forgot': 'password-recovery',
      '/api/auth/password/reset?code=xyz': 'password-recovery',
      '/api/email-connections': 'email',
      '/api/google/callback?code=abc': 'email',
      '/api/news/search': 'news',
      '/api/news/summarize': 'article-summary',
      '/api/news/summaries/id-1': 'article-summary',
      '/api/news-summary': 'news-summary',
      '/api/ai/news-summary': 'news-summary',
      '/api/ai/chat': 'ai',
    };
    for (final entry in cases.entries) {
      final request = Request(
          'GET', Uri.parse('http://localhost' + entry.key));
      final target = resolveUpstream(request, targets)!;
      expect(target.port, targets[entry.value]!.port, reason: entry.key);
      expect(target.path, Uri.parse(entry.key).path, reason: entry.key);
      expect(target.query, Uri.parse(entry.key).query, reason: entry.key);
    }
  });

  test('mantém os checks de serviço existentes', () {
    final req = Request(
        'GET', Uri.parse('http://localhost/api/auth/health/live'));
    expect(resolveUpstream(req, targets).toString(),
        'http://127.0.0.1:3001/health/live');
  });

  test('não aceita hostname arbitrário ou serviço desconhecido', () {
    final unknown = Request(
        'GET', Uri.parse('http://localhost/api/evil/health/live'));
    expect(resolveUpstream(unknown, targets), isNull);
    final external = Request(
        'GET', Uri.parse('http://localhost/api/unknown'));
    expect(resolveUpstream(external, targets), isNull);
  });

  test('origens e cookies protegidos', () {
    final allowed = {'http://localhost:5173'};
    expect(allowedOrigin('http://localhost:5173', allowed), isNotNull);
    expect(allowedOrigin('https://attacker.test', allowed), isNull);
    expect(rejectedMutation(Request('POST',
        Uri.parse('http://x/api/auth/login'),
        headers: {'origin': 'https://attacker.test'}), allowed), isTrue);
    expect(rejectedMutation(Request('POST',
        Uri.parse('http://x/api/auth/login'),
        headers: {'cookie': 'portal_session=x'}), allowed), isTrue);
    expect(rejectedMutation(Request('POST',
        Uri.parse('http://x/api/auth/login')), allowed), isFalse);
  });
}
