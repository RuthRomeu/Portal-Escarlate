import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:portal_core/portal_core.dart';
import 'package:api_gateway/api_gateway.dart';
import 'package:portal_http/portal_http.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const services = <String, int>{
  'auth': 3001,
  'news': 3002,
  'registration': 3003,
  'ai': 3004,
  'email': 3005,
  'news-summary': 3006,
  'article-summary': 3008,
  'password-recovery': 3009,
};

Future<void> main() async {
  final config = ServiceConfig(name: 'api-gateway', defaultPort: 3100);
  final targets = <String, Uri>{};
  for (final service in services.entries) {
    final key = service.key.toUpperCase().replaceAll('-', '_');
    final env = Platform.environment['${key}_SERVICE_URL'];
    targets[service.key] = Uri.parse(env ?? 'http://127.0.0.1:${service.value}');
  }
  final client = http.Client();
  Future<Response> handler(Request request) async {
    if (request.url.path == 'health/live') {
      return jsonReply(200, {'status': 'ok', 'service': 'api-gateway'});
    }
    if (request.method == 'OPTIONS') {
      return Response(204, headers: const {'allow': 'GET, POST, PUT, PATCH, DELETE, OPTIONS'});
    }
    final target = resolveUpstream(request, targets);
    if (target == null) return jsonReply(404, {'error': 'unknown_route'});
    if (config.internalToken == null || config.internalToken!.isEmpty) {
      return jsonReply(503, {'error': 'gateway_not_configured'});
    }
    try {
      final bytes = await request.read().fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      final upstream = http.Request(request.method, target)
        ..followRedirects = false
        ..bodyBytes = bytes;
      for (final name in ['content-type', 'accept', 'cookie', 'authorization', 'x-request-id']) {
        final value = request.headers[name];
        if (value != null) upstream.headers[name] = value;
      }
      upstream.headers['x-internal-token'] = config.internalToken!;
      final streamed = await client.send(upstream).timeout(const Duration(seconds: 15));
      // Não seguir redirects do backend: repassar o status ao frontend.
      final contentType = streamed.headers['content-type'];
      final responseBody = await streamed.stream.toBytes();
      return Response(streamed.statusCode, body: responseBody,
        headers: {if (contentType != null) 'content-type': contentType});
    } catch (error) {
      stderr.writeln('[gateway] $error');
      return jsonReply(502, {'error': 'service_unavailable'});
    }
  }
  final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler(handler);
  final server = await shelf_io.serve(pipeline, config.host, config.port);
  stdout.writeln('[gateway] listening on ${server.address.address}:${server.port}');
  Future<void> shutdown() async { await server.close(force: true); client.close(); }
  ProcessSignal.sigterm.watch().listen((_) => unawaited(shutdown()));
  ProcessSignal.sigint.watch().listen((_) => unawaited(shutdown()));
}
