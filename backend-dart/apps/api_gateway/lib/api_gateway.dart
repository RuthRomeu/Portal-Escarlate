import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:portal_http/portal_http.dart';
import 'package:shelf/shelf.dart';

/// Endpoints públicos existentes: clientes não dependem da topologia interna.
String? serviceForPath(String path) {
  if (path == '/api/auth/register' ||
      path == '/api/auth/register/request' ||
      path == '/api/auth/verify-email') return 'registration';
  if (path == '/api/auth/password/forgot' ||
      path == '/api/auth/password/reset') return 'password-recovery';
  if (path == '/api/auth' || path.startsWith('/api/auth/')) return 'auth';
  if (path == '/api/email-connections' ||
      path.startsWith('/api/email-connections/') ||
      path == '/api/google/callback') return 'email';
  if (path == '/api/news-summary' || path == '/api/ai/news-summary' ||
      path == '/api/ai-summary/news') return 'news-summary';
  if (path == '/api/news/summarize' ||
      path.startsWith('/api/news/summaries/')) return 'article-summary';
  if (path == '/api/news' || path.startsWith('/api/news/')) return 'news';
  if (path == '/api/ai' || path.startsWith('/api/ai/')) return 'ai';
  // Health checks diretos permanecem disponíveis para qualquer serviço configurado.
  final segments = Uri.parse(path).pathSegments;
  if (segments.length == 4 && segments[0] == 'api' &&
      segments[2] == 'health' && segments[3] == 'live') return segments[1];
  return null;
}

/// Um serviço só pode ser acessado por um endereço pré-configurado.
Uri? resolveUpstream(Request request, Map<String, Uri> targets) {
  final path = '/' + request.url.path;
  final service = serviceForPath(path);
  final target = service == null ? null : targets[service];
  if (target == null) return null;

  final segments = request.url.pathSegments;
  final health = segments.length == 4 && segments[0] == 'api' &&
      segments[1] == service && segments[2] == 'health' &&
      segments[3] == 'live';
  return target.replace(
    path: health ? '/health/live' : path,
    query: request.url.hasQuery ? request.url.query : null,
  );
}

String? allowedOrigin(String? raw, Set<String> allowed) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  return allowed.contains(uri.origin) ? uri.origin : null;
}

Set<String> gatewayOrigins(Map<String, String> environment) {
  final origins = <String>{'http://localhost:5173', 'http://127.0.0.1:5173'};
  for (final candidate in [
    if (environment['APP_URL'] != null) environment['APP_URL']!,
    ...?environment['ALLOWED_ORIGINS']?.split(','),
  ]) {
    final uri = Uri.tryParse(candidate.trim());
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https')) origins.add(uri.origin);
  }
  return origins;
}

bool rejectedMutation(Request request, Set<String> origins) {
  if (!{'POST', 'PUT', 'PATCH', 'DELETE'}.contains(request.method)) return false;
  final origin = request.headers['origin'];
  if (origin != null) return allowedOrigin(origin, origins) == null;
  final referer = request.headers['referer'];
  if (referer != null) return allowedOrigin(referer, origins) == null;
  // Clientes nativos sem cookie podem acessar; cookies sem Origin/Referer não.
  return request.headers.containsKey('cookie');
}

const _requestHeaders = [
  'content-type', 'accept', 'authorization', 'cookie', 'x-request-id',
];
const _responseHeaders = [
  'content-type', 'set-cookie', 'location', 'cache-control',
  'etag', 'last-modified', 'retry-after', 'www-authenticate',
  'vary', 'content-disposition',
];

/// Handler injetável: testes podem executar um upstream HTTP simulado.
Handler buildGatewayHandler({
  required Map<String, Uri> targets,
  required String? internalToken,
  required Set<String> origins,
  required HttpClient client,
  Duration timeout = const Duration(seconds: 20),
  int maxRequestBytes = 1024 * 1024,
}) {
  Future<Response> handler(Request request) async {
    final origin = allowedOrigin(request.headers['origin'], origins);
    final cors = <String, String>{
      if (origin != null) ...{
        'access-control-allow-origin': origin,
        'access-control-allow-credentials': 'true',
        'vary': 'Origin',
      },
    };
    Response reply(int status, Object body) =>
        jsonReply(status, body).change(headers: cors);

    if (request.method == 'GET' &&
        (request.url.path == 'health/live' || request.url.path == 'health')) {
      return reply(200, {'status': 'ok', 'service': 'api-gateway'});
    }
    final target = resolveUpstream(request, targets);
    if (target == null) return reply(404, {'error': 'unknown_route'});

    if (request.method == 'OPTIONS') {
      if (origin == null) return reply(403, {'error': 'origin_forbidden'});
      return Response(204, headers: {
        ...cors,
        'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'access-control-allow-headers': 'content-type, authorization, x-request-id',
        'access-control-max-age': '600',
      });
    }
    if ((request.headers['origin'] != null && origin == null) ||
        rejectedMutation(request, origins)) {
      return reply(403, {'error': 'origin_forbidden'});
    }
    if (internalToken == null || internalToken.isEmpty) {
      return reply(503, {'error': 'gateway_not_configured'});
    }

    try {
      final data = BytesBuilder(copy: false);
      await for (final chunk in request.read()) {
        data.add(chunk);
        if (data.length > maxRequestBytes) {
          return reply(413, {'error': 'request_too_large'});
        }
      }

      final upstream = await client.openUrl(request.method, target).timeout(timeout);
      upstream.followRedirects = false;
      for (final name in _requestHeaders) {
        final value = request.headers[name];
        if (value != null) upstream.headers.set(name, value);
      }
      upstream.headers.set('x-internal-token', internalToken);
      final body = data.takeBytes();
      upstream.contentLength = body.length;
      upstream.add(body);

      final response = await upstream.close().timeout(timeout);
      final headers = <String, Object>{...cors};
      for (final name in _responseHeaders) {
        final values = response.headers[name];
        if (values != null && values.isNotEmpty && name != 'vary') {
          headers[name] = values.length == 1 ? values.single : values;
        }
      }
      if (response.headers['vary'] != null) {
        headers['vary'] = origin == null
            ? response.headers['vary']!.join(', ')
            : 'Origin, ' + response.headers['vary']!.join(', ');
      }
      if (response.statusCode == 204 || response.statusCode == 304) {
        await response.drain<void>();
        return Response(response.statusCode, headers: headers);
      }
      // Mantém cookies separados (List<String>) e transmite a resposta.
      return Response(response.statusCode, body: response, headers: headers);
    } on TimeoutException {
      return reply(504, {'error': 'upstream_timeout'});
    } catch (error) {
      stderr.writeln('[gateway] proxy error: $error');
      return reply(502, {'error': 'service_unavailable'});
    }
  }
  return handler;
}
